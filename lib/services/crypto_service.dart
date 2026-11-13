import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// A user-facing problem with an encrypted payload.
class CryptoException implements Exception {
  const CryptoException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Passphrase encryption for private shares and backups.
///
/// PBKDF2-HMAC-SHA256 derives a 256-bit key from the passphrase, then
/// AES-256-GCM encrypts and authenticates the JSON. Everything is local; no
/// key material or passphrase is ever stored.
class CryptoService {
  const CryptoService();

  static const String format = 'ghostthread-encrypted';
  static const int version = 1;
  static const int _iterations = 100000;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;

  Future<String> encryptJson(
    Map<String, dynamic> payload,
    String passphrase,
  ) async {
    if (passphrase.isEmpty) {
      throw const CryptoException('A passphrase is required.');
    }

    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final key = await _deriveKey(passphrase, salt);
    final algorithm = AesGcm.with256bits();

    final box = await algorithm.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: key,
      nonce: nonce,
      aad: _associatedData,
    );

    return jsonEncode(<String, dynamic>{
      'format': format,
      'version': version,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': _iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  Future<Map<String, dynamic>> decryptJson(
    String envelope,
    String passphrase,
  ) async {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(envelope) as Map<String, dynamic>;
    } on Object {
      throw const CryptoException(
        'This does not look like a GhostThread encrypted payload.',
      );
    }

    if (data['format'] != format) {
      throw const CryptoException(
        'This does not look like a GhostThread encrypted payload.',
      );
    }

    try {
      final salt = base64Decode(data['salt'] as String);
      final nonce = base64Decode(data['nonce'] as String);
      final key = await _deriveKey(passphrase, salt);
      final box = SecretBox(
        base64Decode(data['cipherText'] as String),
        nonce: nonce,
        mac: Mac(base64Decode(data['mac'] as String)),
      );

      final clearText = await AesGcm.with256bits().decrypt(
        box,
        secretKey: key,
        aad: _associatedData,
      );
      return jsonDecode(utf8.decode(clearText)) as Map<String, dynamic>;
    } on SecretBoxAuthenticationError {
      throw const CryptoException('Wrong passphrase, or the payload is damaged.');
    } on CryptoException {
      rethrow;
    } on Object {
      throw const CryptoException('Could not decrypt this payload.');
    }
  }

  static List<int> get _associatedData => utf8.encode('$format/v$version');

  static Future<SecretKey> _deriveKey(String passphrase, List<int> salt) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
