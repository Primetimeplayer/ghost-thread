import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_settings.dart';

/// Persists [AppSettings] in its own Hive box.
///
/// `Hive.initFlutter()` is already called by `StorageService.init()` before
/// this runs.
class SettingsService {
  SettingsService._(this._box);

  static const String _boxName = 'ghost_settings';
  static const String _key = 'settings';

  final Box<String> _box;

  static Future<SettingsService> init() async {
    final box = await Hive.openBox<String>(_boxName);
    return SettingsService._(box);
  }

  AppSettings load() {
    final raw = _box.get(_key);
    if (raw == null) {
      return const AppSettings();
    }
    try {
      return AppSettings.fromJson(raw);
    } on Object {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) {
    return _box.put(_key, settings.toJson());
  }
}
