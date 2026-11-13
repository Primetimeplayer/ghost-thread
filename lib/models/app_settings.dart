import 'dart:convert';

/// How the app picks its light or dark theme.
enum AppThemeMode { system, light, dark }

/// User-tunable resurfacing settings, persisted in Hive as JSON.
class AppSettings {
  const AppSettings({
    this.matchSensitivity = defaultSensitivity,
    this.quietStartMinutes = 22 * 60,
    this.quietEndMinutes = 7 * 60,
    this.useTime = true,
    this.useBattery = true,
    this.useLocation = true,
    this.useDevice = true,
    this.themeMode = AppThemeMode.system,
    this.autoKillAfter90Days = false,
  });

  static const double defaultSensitivity = 0.45;
  static const double minSensitivity = 0.2;
  static const double maxSensitivity = 0.8;

  /// Days without interaction before auto-kill may put a thread to rest.
  static const int autoKillAfterDays = 90;

  /// Minimum match score before a thread may be resurfaced.
  final double matchSensitivity;

  /// Quiet hours, stored as minutes past midnight.
  final int quietStartMinutes;
  final int quietEndMinutes;

  final bool useTime;
  final bool useBattery;
  final bool useLocation;
  final bool useDevice;

  final AppThemeMode themeMode;

  /// When on, stale threads are marked inactive on launch/resume.
  final bool autoKillAfter90Days;

  AppSettings copyWith({
    double? matchSensitivity,
    int? quietStartMinutes,
    int? quietEndMinutes,
    bool? useTime,
    bool? useBattery,
    bool? useLocation,
    bool? useDevice,
    AppThemeMode? themeMode,
    bool? autoKillAfter90Days,
  }) {
    return AppSettings(
      matchSensitivity: matchSensitivity ?? this.matchSensitivity,
      quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
      quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
      useTime: useTime ?? this.useTime,
      useBattery: useBattery ?? this.useBattery,
      useLocation: useLocation ?? this.useLocation,
      useDevice: useDevice ?? this.useDevice,
      themeMode: themeMode ?? this.themeMode,
      autoKillAfter90Days: autoKillAfter90Days ?? this.autoKillAfter90Days,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'matchSensitivity': matchSensitivity,
      'quietStartMinutes': quietStartMinutes,
      'quietEndMinutes': quietEndMinutes,
      'useTime': useTime,
      'useBattery': useBattery,
      'useLocation': useLocation,
      'useDevice': useDevice,
      'themeMode': themeMode.name,
      'autoKillAfter90Days': autoKillAfter90Days,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      matchSensitivity:
          (map['matchSensitivity'] as num?)?.toDouble() ?? defaultSensitivity,
      quietStartMinutes: map['quietStartMinutes'] as int? ?? 22 * 60,
      quietEndMinutes: map['quietEndMinutes'] as int? ?? 7 * 60,
      useTime: map['useTime'] as bool? ?? true,
      useBattery: map['useBattery'] as bool? ?? true,
      useLocation: map['useLocation'] as bool? ?? true,
      useDevice: map['useDevice'] as bool? ?? true,
      themeMode: AppThemeMode.values.firstWhere(
        (mode) => mode.name == map['themeMode'],
        orElse: () => AppThemeMode.system,
      ),
      autoKillAfter90Days: map['autoKillAfter90Days'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AppSettings.fromJson(String json) {
    return AppSettings.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Whether [time] falls inside quiet hours. Handles ranges past midnight.
  bool isQuietAt(DateTime time) {
    if (quietStartMinutes == quietEndMinutes) {
      return false;
    }

    final minutes = time.hour * 60 + time.minute;
    if (quietStartMinutes < quietEndMinutes) {
      return minutes >= quietStartMinutes && minutes < quietEndMinutes;
    }
    return minutes >= quietStartMinutes || minutes < quietEndMinutes;
  }
}
