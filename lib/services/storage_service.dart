import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/ghost_thread.dart';

/// Local persistence for ghost threads, backed by a single Hive box.
///
/// Each thread is stored under its `id` as a JSON string, which keeps the
/// schema flexible while later phases add fields.
class StorageService {
  StorageService._(this._box);

  static const String _boxName = 'ghost_threads';

  final Box<String> _box;

  /// Opens the Hive box. Call once before the app starts.
  static Future<StorageService> init() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(_boxName);
    return StorageService._(box);
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
