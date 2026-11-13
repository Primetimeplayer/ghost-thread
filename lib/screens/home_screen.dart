import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../models/ghost_thread.dart';
import '../providers/service_providers.dart';
import '../providers/settings_provider.dart';
import '../providers/thread_providers.dart';
import '../services/embedding_service.dart';
import '../services/matching_service.dart';
import '../widgets/press_scale.dart';
import 'capture_screen.dart';
import 'settings_screen.dart';
import 'thread_detail_screen.dart';

/// Lists every active ghost thread, newest first, with search.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static final DateFormat _dateFormat = DateFormat.yMMMd().add_jm();
  static final DateFormat _shortDate = DateFormat.MMMd().add_jm();
  static const double _similarityFloor = 0.3;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _isMatching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCapture() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CaptureScreen()),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  /// Temporary Phase 3/4 test path: rank threads against the current context.
  Future<void> _findRelevantThreads() async {
    if (_isMatching) {
      return;
    }
    setState(() => _isMatching = true);

    List<ThreadMatch>? matches;
    try {
      matches = await ref
          .read(resurfacingServiceProvider)
          .findRelevant(settings: ref.read(settingsProvider));
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
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Relevant right now', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Context-only preview — time, battery and place. '
                  'Content similarity joins in once a query embedding exists.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (matches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Nothing matched the current context. '
                      'Capture a few more thoughts first.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  for (final match in matches)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ThreadDetailScreen(
                                threadId: match.thread.id,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      match.thread.content,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${(match.score * 100).round()}%',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: theme.colorScheme.primary,
                                        ),
                                  ),
                                ],
                              ),
                              if (match.reasons.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  match.reasons.join(' · '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Puts a thread to rest from a swipe, with an undo action.
  Future<bool> _dismissThread(GhostThread thread) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(storageServiceProvider).softDeleteThread(thread.id);
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update this thread.')),
      );
      return false;
    }

    ref.invalidate(activeThreadsProvider);
    messenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, size: 20),
            SizedBox(width: 8),
            Text('Thread put to rest'),
          ],
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final storage = ref.read(storageServiceProvider);
            final restored = await storage.getThread(thread.id);
            if (restored == null) {
              return;
            }
            await storage.updateThread(restored.copyWith(isActive: true));
            ref.invalidate(activeThreadsProvider);
          },
        ),
      ),
    );
    return true;
  }

  /// Keyword match first, then embedding similarity above a small floor.
  List<GhostThread> _filterThreads(
    List<GhostThread> threads,
    EmbeddingService embeddings,
  ) {
    final query = _query.trim();
    if (query.isEmpty) {
      return threads;
    }

    final queryEmbedding = embeddings.embed(query);
    final lowerQuery = query.toLowerCase();
    final scored = <({GhostThread thread, double score})>[];

    for (final thread in threads) {
      final textMatch = thread.content.toLowerCase().contains(lowerQuery);
      final similarity = embeddings.cosineSimilarity(
        queryEmbedding,
        thread.embedding,
      );
      if (textMatch || similarity >= _similarityFloor) {
        scored.add((thread: thread, score: textMatch ? 1.0 : similarity));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return <GhostThread>[for (final entry in scored) entry.thread];
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search thoughts',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear search',
                onPressed: _clearSearch,
              ),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final threads = ref.watch(activeThreadsProvider);
    final embeddings = ref.watch(embeddingServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GhostThread'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: threads.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(message: error.toString()),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyState(onCapture: _openCapture);
          }

          final visible = _filterThreads(items, embeddings);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildSearchField(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: _isMatching ? null : _findRelevantThreads,
                    icon: _isMatching
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.travel_explore),
                    label: const Text('Find relevant threads'),
                  ),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? _NoMatches(query: _query.trim(), onClear: _clearSearch)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final thread = visible[index];
                          return Dismissible(
                            key: ValueKey<String>(thread.id),
                            direction: DismissDirection.endToStart,
                            background: _SwipeBackground(),
                            confirmDismiss: (_) => _dismissThread(thread),
                            child: _ThreadCard(
                              thread: thread,
                              subtitle: _dateFormat.format(thread.createdAt),
                              surfaceLabel: _surfaceLabel(thread),
                              onLongPress: () {
                                _showSimilarThreads(
                                  context,
                                  thread,
                                  items,
                                  embeddings,
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: PressScale(
        child: FloatingActionButton.large(
          onPressed: _openCapture,
          tooltip: 'Capture a thought',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  static String _surfaceLabel(GhostThread thread) {
    final lastSurfaced = thread.lastSurfaced;
    if (lastSurfaced == null) {
      return 'Resurfaced ${thread.surfaceCount}×';
    }
    return 'Last surfaced ${_shortDate.format(lastSurfaced)}';
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

class _SwipeBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.delete_outline,
        color: theme.colorScheme.onErrorContainer,
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.thread,
    required this.subtitle,
    required this.surfaceLabel,
    required this.onLongPress,
  });

  final GhostThread thread;
  final String subtitle;
  final String surfaceLabel;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle, style: theme.textTheme.bodySmall),
              if (thread.surfaceCount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        surfaceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ThreadDetailScreen(threadId: thread.id),
            ),
          );
        },
        onLongPress: onLongPress,
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

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
              Icons.search_off,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              query.isEmpty ? 'No thoughts to show.' : 'No thoughts match "$query".',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear),
              label: const Text('Clear search'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCapture});

  final VoidCallback onCapture;

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
            Text('Nothing haunting you yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Capture the thought you keep putting off. GhostThread will '
              'bring it back when the moment fits.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.add),
              label: const Text('Capture a thought'),
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
