import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../models/ghost_thread.dart';

/// Read-only view of a single thread.
class ThreadDetailScreen extends StatelessWidget {
  const ThreadDetailScreen({super.key, required this.thread});

  final GhostThread thread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = DateFormat.yMMMd().add_jm().format(thread.createdAt);

    return Scaffold(
      appBar: AppBar(title: const Text('Thread')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(thread.content, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Captured $createdAt',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
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
                  label: Text(
                    'Resurfaced ${thread.surfaceCount}×',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
