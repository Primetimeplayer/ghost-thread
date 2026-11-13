import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/backup_service.dart';
import '../services/export_service.dart';
import '../services/home_widget_service.dart';
import '../services/notification_service.dart';
import '../services/resurfacing_service.dart';
import '../services/share_service.dart';
import 'thread_providers.dart';

/// App-wide notification singleton.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

/// JSON export of all stored threads.
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(storage: ref.watch(storageServiceProvider));
});

/// Pushes the current thread to the home-screen widget.
final homeWidgetServiceProvider = Provider<HomeWidgetService>((ref) {
  return const HomeWidgetService();
});

/// Passphrase-encrypted sharing of a single thread.
final shareServiceProvider = Provider<ShareService>((ref) {
  return const ShareService();
});

/// Passphrase-encrypted local backups.
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(storage: ref.watch(storageServiceProvider));
});

/// Resurfacing rules: quiet hours, sensitivity, once-per-day.
final resurfacingServiceProvider = Provider<ResurfacingService>((ref) {
  return ResurfacingService(
    storage: ref.watch(storageServiceProvider),
    context: ref.watch(contextServiceProvider),
    matching: ref.watch(matchingServiceProvider),
    notifications: ref.watch(notificationServiceProvider),
  );
});
