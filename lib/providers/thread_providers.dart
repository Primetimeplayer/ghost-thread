import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ghost_thread.dart';
import '../services/context_service.dart';
import '../services/embedding_service.dart';
import '../services/matching_service.dart';
import '../services/storage_service.dart';

/// The app-wide storage service.
///
/// Overridden in `main()` once Hive has been initialized.
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError(
    'storageServiceProvider must be overridden with an initialized '
    'StorageService before the app starts.',
  );
});

/// Active threads, newest first. Invalidate after saving to refresh the list.
final activeThreadsProvider = FutureProvider<List<GhostThread>>((ref) {
  return ref.watch(storageServiceProvider).getActiveThreads();
});

/// A single thread by id, reloaded after updates.
final threadProvider = FutureProvider.family<GhostThread?, String>((ref, id) {
  return ref.watch(storageServiceProvider).getThread(id);
});

/// Deterministic mock embeddings. Override this once a real on-device model
/// is wired up.
final embeddingServiceProvider = Provider<EmbeddingService>((ref) {
  return const EmbeddingService();
});

/// Ambient context capture (time, battery, place, device).
final contextServiceProvider = Provider<ContextService>((ref) {
  return ContextService();
});

/// Ranks active threads against the current context and a query embedding.
final matchingServiceProvider = Provider<MatchingService>((ref) {
  return MatchingService(embeddings: ref.watch(embeddingServiceProvider));
});
