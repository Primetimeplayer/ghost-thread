import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../models/ghost_thread.dart';
import '../providers/thread_providers.dart';
import '../services/embedding_service.dart';
import '../services/matching_service.dart';
import 'capture_screen.dart';
import 'thread_detail_screen.dart';

/// Lists every active ghost thread, newest first.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static final DateFormat _dateFormat = DateFormat.yMMMd().add_jm();

  bool _isMatching = false;

  /// Temporary Phase 3 test path: rank threads against the current context.
  Future<void> _findRelevantThreads() async {
    if (_isMatching) {
      return;
    }
    setState(() => _isMatching = true);

    List<ThreadMatch>? matches;
    try {
      final threads = await ref.read(activeThreadsProvider.future);
      final context = await ref.read(contextServiceProvider).captureContext();
      matches = ref
          .read(matchingServiceProvider)
          .rankThreads(threads: threads, context: context, limit: 5);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find relevant threads.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isMatching = false);
      }
    }

    if (!mounted || matches == null) {
      return;
    }
    await _showMatches(matches);
  }

  Future<void> _showMatches(List<ThreadMatch> matches) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Relevant right now', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Context-only preview — time, battery and place. '
                  'Content similarity joins in once a query embedding exists.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                if (matches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Nothing matched the current context.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  for (final match in matches)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        match.thread.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        match.reasons.isEmpty
                            ? 'No strong shared signals'
                            : match.reasons.join(' · '),
                      ),
                      trailing: Text(
                        '${(match.score * 100).round()}%',
                        style: theme.textTheme.titleMedium,
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ThreadDetailScreen(thread: match.thread),
                          ),
                        );
                      },
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final threads = ref.watch(activeThreadsProvider);
    final embeddings = ref.watch(embeddingServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('GhostThread')),
      body: threads.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(message: error.toString()),
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        onPressed: _isMatching ? null : _findRelevantThreads,
                        icon: _isMatching
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.travel_explore),
                        label: const Text('Find relevant threads'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final thread = items[index];
                        return _ThreadCard(
                          thread: thread,
                          subtitle: _dateFormat.format(thread.createdAt),
                          onLongPress: () {
                            _showSimilarThreads(context, thread, items, embeddings);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CaptureScreen()),
          );
        },
        tooltip: 'Capture a thought',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Temporary debug view: the three threads whose mock embeddings are closest
/// to [selected]. Long-press a thread to open it.
Future<void> _showSimilarThreads(
  BuildContext context,
  GhostThread selected,
  List<GhostThread> allThreads,
  EmbeddingService embeddings,
) {
  final ranked = <({GhostThread thread, double score})>[
    for (final thread in allThreads)
      if (thread.id != selected.id)
        (
          thread: thread,
          score: embeddings.cosineSimilarity(
            selected.embedding,
            thread.embedding,
          ),
        ),
  ]..sort((a, b) => b.score.compareTo(a.score));
  final top = ranked.take(3).toList();

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Most similar threads', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Debug preview — cosine similarity of mock embeddings',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (top.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No other threads to compare yet.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                for (final entry in top)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      entry.thread.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _HomeScreenState._dateFormat.format(
                        entry.thread.createdAt,
                      ),
                    ),
                    trailing: Text(
                      entry.score.toStringAsFixed(3),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
            ],
          ),
        ),
      );
    },
  );
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.thread,
    required this.subtitle,
    required this.onLongPress,
  });

  final GhostThread thread;
  final String subtitle;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          thread.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle, style: theme.textTheme.bodySmall),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ThreadDetailScreen(thread: thread),
            ),
          );
        },
        onLongPress: onLongPress,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('No thoughts yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap + to capture the thought you keep putting off.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Could not load your threads.\n$message',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
