import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../providers/settings_provider.dart';
import '../services/install_prompt_service.dart';

/// A quiet "Install GhostThread" card, shown only when the browser offers the
/// install prompt and the user has not dismissed it before.
class InstallBanner extends ConsumerStatefulWidget {
  const InstallBanner({super.key});

  @override
  ConsumerState<InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends ConsumerState<InstallBanner> {
  late final InstallPromptController _controller;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = createInstallPromptController();
    _controller.canInstall.addListener(_onAvailabilityChanged);
    _controller.init();
  }

  void _onAvailabilityChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.canInstall.removeListener(_onAvailabilityChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _install() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final installed = await _controller.promptInstall();
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (installed) {
      messenger.showSnackBar(
        const SnackBar(content: Text('GhostThread installed')),
      );
    }
  }

  Future<void> _dismiss() async {
    await ref.read(settingsProvider.notifier).setInstallPromptDismissed(true);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final available =
        _controller.canInstall.value &&
        !_controller.isInstalled &&
        !settings.installPromptDismissed;

    if (!available) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.install_desktop_outlined,
                    size: 20,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Install GhostThread',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 2),
                child: Text(
                  'Opens full screen and works offline, like an app.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy ? null : _dismiss,
                    child: const Text('Not now'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: _busy ? null : _install,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Install'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
