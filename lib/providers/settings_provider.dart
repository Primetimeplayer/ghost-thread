import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../services/settings_service.dart';

/// The app-wide settings store.
///
/// Overridden in `main()` once Hive has been initialized.
final settingsServiceProvider = Provider<SettingsService>((ref) {
  throw UnimplementedError(
    'settingsServiceProvider must be overridden with an initialized '
    'SettingsService before the app starts.',
  );
});

/// Current resurfacing settings. Changes are persisted immediately.
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsServiceProvider).load();

  Future<void> setSensitivity(double value) {
    return _update(
      state.copyWith(
        matchSensitivity: value
            .clamp(AppSettings.minSensitivity, AppSettings.maxSensitivity)
            .toDouble(),
      ),
    );
  }

  Future<void> setQuietStart(int minutes) {
    return _update(state.copyWith(quietStartMinutes: minutes));
  }

  Future<void> setQuietEnd(int minutes) {
    return _update(state.copyWith(quietEndMinutes: minutes));
  }

  Future<void> setUseTime(bool value) {
    return _update(state.copyWith(useTime: value));
  }

  Future<void> setUseBattery(bool value) {
    return _update(state.copyWith(useBattery: value));
  }

  Future<void> setUseLocation(bool value) {
    return _update(state.copyWith(useLocation: value));
  }

  Future<void> setUseDevice(bool value) {
    return _update(state.copyWith(useDevice: value));
  }

  Future<void> setThemeMode(AppThemeMode value) {
    return _update(state.copyWith(themeMode: value));
  }

  Future<void> setAutoKill(bool value) {
    return _update(state.copyWith(autoKillAfter90Days: value));
  }

  /// Replaces every setting, used after restoring a backup.
  Future<void> replace(AppSettings next) => _update(next);

  Future<void> _update(AppSettings next) async {
    state = next;
    await ref.read(settingsServiceProvider).save(next);
  }
}
