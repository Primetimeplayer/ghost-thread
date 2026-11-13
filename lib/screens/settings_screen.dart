import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../models/app_settings.dart';
import '../providers/service_providers.dart';
import '../providers/settings_provider.dart';

/// Appearance, resurfacing, context signals and data export.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _SectionHeader(title: 'Appearance'),
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(_themeLabel(settings.themeMode)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(value: AppThemeMode.system, label: Text('System')),
                ButtonSegment(value: AppThemeMode.light, label: Text('Light')),
                ButtonSegment(value: AppThemeMode.dark, label: Text('Dark')),
              ],
              selected: {settings.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                notifier.setThemeMode(selection.first);
              },
            ),
          ),
          const Divider(),
          const _SectionHeader(title: 'Resurfacing'),
          ListTile(
            title: const Text('Matching sensitivity'),
            subtitle: Text(
              'Only resurface threads scoring '
              '${(settings.matchSensitivity * 100).round()}% or higher.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: settings.matchSensitivity,
              min: AppSettings.minSensitivity,
              max: AppSettings.maxSensitivity,
              divisions: 12,
              label: '${(settings.matchSensitivity * 100).round()}%',
              onChanged: notifier.setSensitivity,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bedtime_outlined),
            title: const Text('Quiet hours'),
            subtitle: Text(
              '${_formatMinutes(context, settings.quietStartMinutes)} – '
              '${_formatMinutes(context, settings.quietEndMinutes)}',
            ),
          ),
          ListTile(
            title: const Text('Quiet hours start'),
            trailing: Text(
              _formatMinutes(context, settings.quietStartMinutes),
            ),
            onTap: () => _pickQuietHour(context, ref, isStart: true),
          ),
          ListTile(
            title: const Text('Quiet hours end'),
            trailing: Text(_formatMinutes(context, settings.quietEndMinutes)),
            onTap: () => _pickQuietHour(context, ref, isStart: false),
          ),
          const Divider(),
          const _SectionHeader(title: 'Context signals'),
          SwitchListTile(
            title: const Text('Time of day'),
            subtitle: const Text('Hour and weekday of capture'),
            value: settings.useTime,
            onChanged: notifier.setUseTime,
          ),
          SwitchListTile(
            title: const Text('Battery'),
            subtitle: const Text('Battery level of capture'),
            value: settings.useBattery,
            onChanged: notifier.setUseBattery,
          ),
          SwitchListTile(
            title: const Text('Location'),
            subtitle: const Text('Approximate place of capture'),
            value: settings.useLocation,
            onChanged: notifier.setUseLocation,
          ),
          SwitchListTile(
            title: const Text('Device'),
            subtitle: const Text('Platform and device model'),
            value: settings.useDevice,
            onChanged: notifier.setUseDevice,
          ),
          const Divider(),
          const _SectionHeader(title: 'Housekeeping'),
          SwitchListTile(
            title: const Text('Auto-kill after 90 days'),
            subtitle: const Text(
              'Threads with no interaction for 90 days are put to rest. '
              'Nothing is deleted and exports still include them.',
            ),
            value: settings.autoKillAfter90Days,
            onChanged: notifier.setAutoKill,
          ),
          const Divider(),
          const _SectionHeader(title: 'Data'),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Export threads as JSON'),
            subtitle: const Text(
              'Active and finished threads, saved on this device',
            ),
            onTap: () => _export(context, ref),
          ),
        ],
      ),
    );
  }
}

String _themeLabel(AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.system => 'Follows your device setting',
    AppThemeMode.light => 'Always light',
    AppThemeMode.dark => 'Always dark',
  };
}

String _formatMinutes(BuildContext context, int minutes) {
  final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  return MaterialLocalizations.of(context).formatTimeOfDay(
    time,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

Future<void> _pickQuietHour(
  BuildContext context,
  WidgetRef ref, {
  required bool isStart,
}) async {
  final settings = ref.read(settingsProvider);
  final minutes = isStart
      ? settings.quietStartMinutes
      : settings.quietEndMinutes;

  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
  );
  if (picked == null) {
    return;
  }

  final value = picked.hour * 60 + picked.minute;
  final notifier = ref.read(settingsProvider.notifier);
  await (isStart ? notifier.setQuietStart(value) : notifier.setQuietEnd(value));
}

Future<void> _export(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);

  try {
    final path = await ref.read(exportServiceProvider).exportThreads();
    messenger.showSnackBar(SnackBar(content: Text('Exported to $path')));
  } on UnsupportedError {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('JSON export is not available in the browser yet.'),
      ),
    );
  } on Object {
    messenger.showSnackBar(
      const SnackBar(content: Text('Export failed. Please try again.')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
