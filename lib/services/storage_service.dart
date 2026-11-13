import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/ghost_thread.dart';
import 'embedding_service.dart';

/// Local persistence for ghost threads, backed by a single Hive box.
///
/// Each thread is stored under its `id` as a JSON string, which keeps the
/// schema flexible while later phases add fields.
class StorageService {
  StorageService._(this._box, this._metaBox);

  static const String _boxName = 'ghost_threads';
  static const String _metaBoxName = 'ghost_meta';
  static const String _embeddingBackfillKey = 'embedding_backfill_v1';

  final Box<String> _box;

  /// Small key/value box for migration flags.
  final Box<dynamic> _metaBox;

  /// Opens the Hive boxes. Call once before the app starts.
  static Future<StorageService> init() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(_boxName);
    final metaBox = await Hive.openBox<dynamic>(_metaBoxName);
    return StorageService._(box, metaBox);
  }

  /// Fills in embeddings for threads saved before embeddings existed.
  ///
  /// Runs at most once, guarded by a flag in Hive. Threads that already have a
  /// non-zero embedding are left untouched. Returns how many were updated.
  Future<int> backfillEmbeddings(EmbeddingService embeddings) async {
    if (_metaBox.get(_embeddingBackfillKey) == true) {
      return 0;
    }

    var updated = 0;
    // Materialize first: writing to the box while iterating it is unsafe.
    for (final thread in _readAll().toList(growable: false)) {
      if (!_needsEmbedding(thread)) {
        continue;
      }

      await updateThread(thread.copyWith(embedding: embeddings.embed(thread.content)));
      updated++;
    }

    await _metaBox.put(_embeddingBackfillKey, true);
    return updated;
  }

  static bool _needsEmbedding(GhostThread thread) {
    if (thread.content.trim().isEmpty) {
      return false;
    }
    if (thread.embedding.isEmpty) {
      return true;
    }
    return thread.embedding.every((value) => value == 0);
  }

  /// Saves a new thread, or replaces the stored thread with the same id.
  Future<void> saveThread(GhostThread thread) {
    return _box.put(thread.id, thread.toJson());
  }

  /// Overwrites an existing thread.
  Future<void> updateThread(GhostThread thread) {
    return _box.put(thread.id, thread.toJson());
  }

  /// All threads that are still active, newest first.
  Future<List<GhostThread>> getActiveThreads() async {
    final threads = _readAll().where((thread) => thread.isActive).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return threads;
  }

  /// A single thread by id, or `null` if it does not exist.
  Future<GhostThread?> getThread(String id) async {
    final raw = _box.get(id);
    if (raw == null) {
      return null;
    }
    return _decode(raw);
  }

  /// Hides a thread without removing it from storage.
  Future<void> softDeleteThread(String id) async {
    final thread = await getThread(id);
    if (thread == null) {
      return;
    }
    await updateThread(thread.copyWith(isActive: false));
  }

  Iterable<GhostThread> _readAll() sync* {
    for (final raw in _box.values) {
      try {
        yield _decode(raw);
      } on Object catch (error) {
        debugPrint('Skipping unreadable ghost thread: $error');
      }
    }
  }

  GhostThread _decode(String raw) {
    return GhostThread.fromJson(raw);
  }
}
