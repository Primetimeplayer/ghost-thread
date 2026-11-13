import 'dart:ui';

import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/ghost_thread.dart';
import 'crypto_service.dart';

/// Local-only sharing: the thread is encrypted with a passphrase, then handed
/// to the system share sheet as text. No link, no server, no account.
class ShareService {
  const ShareService({this.crypto = const CryptoService()});

  static const String payloadPrefix = 'GHOSTTHREAD-PRIVATE:';

  final CryptoService crypto;

  Future<String> createPayload(GhostThread thread, String passphrase) async {
    final envelope = await crypto.encryptJson(<String, dynamic>{
      'type': 'ghost_thread',
      'sharedAt': DateTime.now().toIso8601String(),
      'thread': <String, dynamic>{
        'content': thread.content,
        'createdAt': thread.createdAt.toIso8601String(),
        'contextAtCreation': thread.contextAtCreation,
        'embedding': thread.embedding,
      },
    }, passphrase);

    return '$payloadPrefix$envelope';
  }

  /// Decrypts [payload] and returns it as a fresh local thread.
  Future<GhostThread> importPayload(
    String payload,
    String passphrase,
  ) async {
    final trimmed = payload.trim();
    final blob = trimmed.startsWith(payloadPrefix)
        ? trimmed.substring(payloadPrefix.length)
        : trimmed;

    final data = await crypto.decryptJson(blob, passphrase);
    if (data['type'] != 'ghost_thread') {
      throw const CryptoException('This payload is not a shared thread.');
    }

    final raw = data['thread'];
    if (raw is! Map) {
      throw const CryptoException('This payload has no thread in it.');
    }
    final thread = Map<String, dynamic>.from(raw);
    final content = (thread['content'] as String? ?? '').trim();
    if (content.isEmpty) {
      throw const CryptoException('The shared thread is empty.');
    }

    return GhostThread(
      id: const Uuid().v4(),
      content: content,
      createdAt:
          DateTime.tryParse(thread['createdAt'] as String? ?? '') ??
          DateTime.now(),
      contextAtCreation: Map<String, dynamic>.from(
        thread['contextAtCreation'] as Map? ?? const <String, dynamic>{},
      ),
      embedding:
          (thread['embedding'] as List?)
              ?.map((value) => (value as num).toDouble())
              .toList(growable: false) ??
          const <double>[],
    );
  }

  Future<void> shareThread({
    required GhostThread thread,
    required String passphrase,
    Rect? sharePositionOrigin,
  }) async {
    final payload = await createPayload(thread, passphrase);
    await SharePlus.instance.share(
      ShareParams(
        text: payload,
        subject: 'GhostThread private thought',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
