import 'package:flutter/foundation.dart';

/// No-op install prompt controller for native builds and unsupported browsers.
class InstallPromptController {
  final ValueNotifier<bool> canInstall = ValueNotifier<bool>(false);

  /// Native builds are installed by definition, so this stays true.
  bool get isInstalled => true;

  Future<void> init() async {}

  Future<bool> promptInstall() async => false;

  void dispose() {
    canInstall.dispose();
  }
}

InstallPromptController createInstallPromptController() {
  return InstallPromptController();
}
