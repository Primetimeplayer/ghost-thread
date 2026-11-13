import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('window')
external _Window get _window;

extension type _Window._(JSObject _) implements JSObject {
  external _MediaQueryList matchMedia(String query);
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension type _MediaQueryList._(JSObject _) implements JSObject {
  external bool get matches;
}

extension type _BeforeInstallPromptEvent._(JSObject _) implements JSObject {
  external void preventDefault();
  external JSPromise<JSAny?> prompt();
  external JSPromise<_InstallChoice> get userChoice;
}

extension type _InstallChoice._(JSObject _) implements JSObject {
  external String get outcome;
}

/// Wraps the browser `beforeinstallprompt` flow.
///
/// The event is captured once and kept until the user accepts, dismisses it,
/// or installs the app another way.
class InstallPromptController {
  final ValueNotifier<bool> canInstall = ValueNotifier<bool>(false);

  _BeforeInstallPromptEvent? _deferred;
  JSFunction? _promptListener;
  JSFunction? _installedListener;
  bool _installedByEvent = false;

  bool get isInstalled => _installedByEvent || _isStandalone;

  Future<void> init() async {
    if (_isStandalone) {
      _installedByEvent = true;
      return;
    }

    final promptListener = ((JSAny event) {
      final promptEvent = _BeforeInstallPromptEvent._(event as JSObject);
      // Keep the browser's mini-infobar out of the way; the app asks instead.
      promptEvent.preventDefault();
      _deferred = promptEvent;
      canInstall.value = true;
    }).toJS;
    _promptListener = promptListener;
    _window.addEventListener('beforeinstallprompt', promptListener);

    final installedListener = ((JSAny event) {
      _installedByEvent = true;
      _deferred = null;
      canInstall.value = false;
    }).toJS;
    _installedListener = installedListener;
    _window.addEventListener('appinstalled', installedListener);
  }

  Future<bool> promptInstall() async {
    final event = _deferred;
    if (event == null) {
      return false;
    }

    _deferred = null;
    canInstall.value = false;

    try {
      await event.prompt().toDart;
      final choice = await event.userChoice.toDart;
      if (choice.outcome == 'accepted') {
        _installedByEvent = true;
        return true;
      }
    } on Object catch (error) {
      debugPrint('Install prompt unavailable: $error');
    }
    return false;
  }

  bool get _isStandalone =>
      _window.matchMedia('(display-mode: standalone)').matches;

  void dispose() {
    final promptListener = _promptListener;
    if (promptListener != null) {
      _window.removeEventListener('beforeinstallprompt', promptListener);
    }
    final installedListener = _installedListener;
    if (installedListener != null) {
      _window.removeEventListener('appinstalled', installedListener);
    }
    canInstall.dispose();
  }
}

InstallPromptController createInstallPromptController() {
  return InstallPromptController();
}
