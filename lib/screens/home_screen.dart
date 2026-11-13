import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../models/ghost_thread.dart';
import '../providers/thread_providers.dart';
import 'capture_screen.dart';
import 'thread_detail_screen.dart';

/// Lists every active ghost thread, newest first.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static final DateFormat _dateFormat = DateFormat.yMMMd().add_jm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(activeThreadsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('GhostThread')),
      body: threads.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(message: error.toString()),
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final thread = items[index];
                  return _ThreadCard(
                    thread: thread,
                    subtitle: _dateFormat.format(thread.createdAt),
                  );
                },
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

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.thread, required this.subtitle});

  final GhostThread thread;
  final String subtitle;

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
