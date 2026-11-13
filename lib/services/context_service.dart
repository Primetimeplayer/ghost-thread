import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Keys written into [GhostThread.contextAtCreation].
///
/// Shared with `MatchingService` so capture and scoring never drift apart.
abstract final class ContextKeys {
  static const String hour = 'hour';
  static const String weekday = 'weekday';
  static const String isWeekend = 'isWeekend';
  static const String timeZoneOffsetMinutes = 'timeZoneOffsetMinutes';
  static const String timeZoneName = 'timeZoneName';
  static const String platform = 'platform';
  static const String deviceModel = 'deviceModel';
  static const String batteryLevel = 'batteryLevel';
  static const String batteryState = 'batteryState';
  static const String latitude = 'latitude';
  static const String longitude = 'longitude';
  static const String locationAccuracyMeters = 'locationAccuracyMeters';
}

/// Collects lightweight ambient context, fully on-device.
///
/// Every signal is best-effort: anything unavailable (permission denied, plugin
/// missing on the platform) is simply left out of the map rather than failing
/// the capture.
class ContextService {
  ContextService({
    Battery? battery,
    DeviceInfoPlugin? deviceInfo,
    DateTime Function()? clock,
  }) : _battery = battery ?? Battery(),
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
       _clock = clock ?? DateTime.now;

  final Battery _battery;
  final DeviceInfoPlugin _deviceInfo;
  final DateTime Function() _clock;

  static const Duration _locationTimeout = Duration(seconds: 4);

  /// Signals known immediately, without any plugin round-trips.
  Future<Map<String, dynamic>> captureContext() async {
    final now = _clock();

    return <String, dynamic>{
      ContextKeys.hour: now.hour,
      ContextKeys.weekday: now.weekday,
      ContextKeys.isWeekend:
          now.weekday == DateTime.saturday || now.weekday == DateTime.sunday,
      ContextKeys.timeZoneOffsetMinutes: now.timeZoneOffset.inMinutes,
      ContextKeys.timeZoneName: now.timeZoneName,
      ContextKeys.platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
      ...await _batteryContext(),
      ...await _deviceContext(),
      ...await _locationContext(),
    };
  }

  Future<Map<String, dynamic>> _batteryContext() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      return <String, dynamic>{
        ContextKeys.batteryLevel: level,
        if (state != BatteryState.unknown)
          ContextKeys.batteryState: state.name,
      };
    } on Object catch (error) {
      debugPrint('Battery context unavailable: $error');
      return const <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> _deviceContext() async {
    try {
      final model = await _deviceModel();
      if (model == null || model.isEmpty) {
        return const <String, dynamic>{};
      }
      return <String, dynamic>{ContextKeys.deviceModel: model};
    } on Object catch (error) {
      debugPrint('Device context unavailable: $error');
      return const <String, dynamic>{};
    }
  }

  Future<String?> _deviceModel() async {
    if (kIsWeb) {
      final info = await _deviceInfo.webBrowserInfo;
      return info.browserName.name;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final info = await _deviceInfo.androidInfo;
        return '${info.manufacturer} ${info.model}'.trim();
      case TargetPlatform.iOS:
        final info = await _deviceInfo.iosInfo;
        return info.utsname.machine;
      default:
        return null;
    }
  }

  /// Approximate location, only when the app already has permission.
  ///
  /// Never prompts: a capture should not be interrupted by a permission dialog.
  Future<Map<String, dynamic>> _locationContext() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const <String, dynamic>{};
      }

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return const <String, dynamic>{};
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: _locationTimeout,
        ),
      );

      return <String, dynamic>{
        // ~11 m precision is plenty for matching and keeps data coarse.
        ContextKeys.latitude: _round(position.latitude),
        ContextKeys.longitude: _round(position.longitude),
        ContextKeys.locationAccuracyMeters: _round(position.accuracy),
      };
    } on Object catch (error) {
      debugPrint('Location context unavailable: $error');
      return const <String, dynamic>{};
    }
  }

  static double _round(double value) => double.parse(value.toStringAsFixed(4));
}
