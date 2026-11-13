import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../providers/service_providers.dart';
import '../providers/settings_provider.dart';
import '../providers/thread_providers.dart';

/// Runs the resurfacing and auto-kill checks on launch and on resume.
class ResurfaceWatcher extends ConsumerStatefulWidget {
  const ResurfaceWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ResurfaceWatcher> createState() => _ResurfaceWatcherState();
}

class _ResurfaceWatcherState extends ConsumerState<ResurfaceWatcher>
    with WidgetsBindingObserver {
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  Future<void> _check() async {
    if (_isChecking || !mounted) {
      return;
    }
    _isChecking = true;

    try {
      final settings = ref.read(settingsProvider);
      final resurfacing = ref.read(resurfacingServiceProvider);

      final killed = await resurfacing.autoKillStale(
        enabled: settings.autoKillAfter90Days,
      );
      if (killed > 0) {
        ref.invalidate(activeThreadsProvider);
      }

      // Notifications are a mobile feature in this phase; the browser is
      // skipped so threads are not marked as surfaced with nothing shown.
      if (!kIsWeb) {
        final match = await resurfacing.checkAndResurface(settings: settings);
        if (match != null) {
          // lastSurfaced / surfaceCount changed on disk.
          ref.invalidate(activeThreadsProvider);
        }
      }
    } on Object catch (error) {
      debugPrint('Resurfacing check skipped: $error');
    } finally {
      _isChecking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
