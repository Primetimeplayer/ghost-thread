import 'dart:convert';

import 'export_writer_stub.dart'
    if (dart.library.io) 'export_writer_io.dart' as writer;
import 'storage_service.dart';

/// Writes every stored thread (active and killed) to a pretty-printed JSON
/// file and returns its path.
///
/// The file writer is platform-specific: `dart:io` is unavailable on web, so
/// the browser build uses a stub that reports the feature as unavailable.
class ExportService {
  ExportService({required this.storage});

  final StorageService storage;

  Future<String> exportThreads() async {
    final threads = await storage.getAllThreads();
    final json = const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'app': 'ghost_thread',
      'exportedAt': DateTime.now().toIso8601String(),
      'threadCount': threads.length,
      'threads': <Map<String, dynamic>>[
        for (final thread in threads) thread.toMap(),
      ],
    });

    return writer.writeExportFile(json);
  }
}
