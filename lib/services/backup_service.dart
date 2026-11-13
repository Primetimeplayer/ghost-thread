import 'backup_storage_stub.dart'
    if (dart.library.io) 'backup_storage_io.dart';
import '../models/app_settings.dart';
import '../models/ghost_thread.dart';
import 'crypto_service.dart';
import 'storage_service.dart';

/// The decrypted contents of a backup file.
class BackupContents {
  const BackupContents({required this.threads, required this.settings});

  final List<GhostThread> threads;
  final AppSettings? settings;
}

/// Encrypted, local-only backups of every thread plus settings.
///
/// File handling is platform-specific: the browser build has no app documents
/// directory, so it reports the feature as unavailable.
class BackupService {
  const BackupService({
    required this.storage,
    this.crypto = const CryptoService(),
  });

  final StorageService storage;
  final CryptoService crypto;

  /// Writes an encrypted backup file and returns its path.
  Future<String> createBackup({
    required AppSettings settings,
    required String passphrase,
  }) async {
    final threads = await storage.getAllThreads();
    final envelope = await crypto.encryptJson(<String, dynamic>{
      'type': 'ghost_thread_backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings.toMap(),
      'threads': <Map<String, dynamic>>[
        for (final thread in threads) thread.toMap(),
      ],
    }, passphrase);

    return writeBackupFile(envelope);
  }

  Future<List<String>> listBackups() => listBackupFiles();

  /// Decrypts a backup file. Throws [CryptoException] on a wrong passphrase.
  Future<BackupContents> readBackup({
    required String path,
    required String passphrase,
  }) async {
    final envelope = await readBackupFile(path);
    final data = await crypto.decryptJson(envelope, passphrase);

    if (data['type'] != 'ghost_thread_backup') {
      throw const CryptoException('This file is not a GhostThread backup.');
    }

    final threads = <GhostThread>[];
    for (final raw in data['threads'] as List? ?? const <Object?>[]) {
      if (raw is Map) {
        threads.add(GhostThread.fromMap(Map<String, dynamic>.from(raw)));
      }
    }

    final settingsRaw = data['settings'];
    return BackupContents(
      threads: threads,
      settings: settingsRaw is Map
          ? AppSettings.fromMap(Map<String, dynamic>.from(settingsRaw))
          : null,
    );
  }

  /// Restores [backup], either replacing everything or merging new ids only.
  /// Returns how many threads were written.
  Future<int> restore(BackupContents backup, {required bool replace}) async {
    if (replace) {
      await storage.clearThreads();
    }

    var written = 0;
    for (final thread in backup.threads) {
      if (!replace && await storage.getThread(thread.id) != null) {
        continue;
      }
      await storage.saveThread(thread);
      written++;
    }
    return written;
  }
}
