import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../models/ghost_thread.dart';
import '../providers/thread_providers.dart';

/// Single thread with Continue / Kill actions.
class ThreadDetailScreen extends ConsumerWidget {
  const ThreadDetailScreen({super.key, required this.threadId});

  final String threadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thread = ref.watch(threadProvider(threadId));

    return Scaffold(
      appBar: AppBar(title: const Text('Thread')),
      body: thread.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Could not load this thread.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (value) => value == null
            ? const Center(child: Text('This thread no longer exists.'))
            : _ThreadDetailBody(
                thread: value,
                onContinue: () => _markContinued(context, ref, value),
                onKill: () => _kill(context, ref, value),
              ),
      ),
    );
  }
}

Future<void> _markContinued(
  BuildContext context,
  WidgetRef ref,
  GhostThread thread,
) async {
  final messenger = ScaffoldMessenger.of(context);

  try {
    await ref.read(storageServiceProvider).updateThread(
      thread.copyWith(
        lastSurfaced: DateTime.now(),
        surfaceCount: thread.surfaceCount + 1,
      ),
    );
  } on Object {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not update this thread.')),
    );
    return;
  }

  ref.invalidate(threadProvider(thread.id));
  ref.invalidate(activeThreadsProvider);
  messenger.showSnackBar(
    const SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 20),
          SizedBox(width: 8),
          Text('Kept for later'),
        ],
      ),
    ),
  );
}

Future<void> _kill(
  BuildContext context,
  WidgetRef ref,
  GhostThread thread,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  try {
    await ref.read(storageServiceProvider).softDeleteThread(thread.id);
  } on Object {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not update this thread.')),
    );
    return;
  }

  ref.invalidate(threadProvider(thread.id));
  ref.invalidate(activeThreadsProvider);
  navigator.pop();
  messenger.showSnackBar(
    const SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 20),
          SizedBox(width: 8),
          Text('Thread put to rest'),
        ],
      ),
    ),
  );
}

class _ThreadDetailBody extends StatelessWidget {
  const _ThreadDetailBody({
    required this.thread,
    required this.onContinue,
    required this.onKill,
  });

  final GhostThread thread;
  final VoidCallback onContinue;
  final VoidCallback onKill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = DateFormat.yMMMd().add_jm().format(thread.createdAt);
    final lastSurfaced = thread.lastSurfaced;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(thread.content, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 24),
        _MetaRow(icon: Icons.schedule, text: 'Captured $createdAt'),
        if (lastSurfaced != null) ...[
          const SizedBox(height: 8),
          _MetaRow(
            icon: Icons.notifications_none,
            text:
                'Last surfaced '
                '${DateFormat.yMMMd().add_jm().format(lastSurfaced)}',
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            Chip(
              label: Text(thread.isActive ? 'Active' : 'Put to rest'),
              visualDensity: VisualDensity.compact,
            ),
            if (thread.surfaceCount > 0)
              Chip(
                label: Text('Resurfaced ${thread.surfaceCount}×'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 32),
        if (thread.isActive) ...[
          FilledButton.icon(
            onPressed: onContinue,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Continue'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onKill,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Kill thread'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        ] else
          Text(
            'This thought is at rest. It no longer appears on the home list.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
