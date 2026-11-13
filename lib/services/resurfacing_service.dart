import '../models/app_settings.dart';
import 'context_service.dart';
import 'matching_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

/// Decides which thread is worth resurfacing right now.
///
/// Kept free of Flutter concerns so the rules stay easy to follow: quiet
/// hours, signal toggles, the sensitivity threshold, and one surface per
/// thread per day.
class ResurfacingService {
  ResurfacingService({
    required this.storage,
    required this.context,
    required this.matching,
    required this.notifications,
  });

  final StorageService storage;
  final ContextService context;
  final MatchingService matching;
  final NotificationService notifications;

  /// Ranks active threads against the current moment.
  Future<List<ThreadMatch>> findRelevant({
    required AppSettings settings,
    int limit = 5,
  }) async {
    final threads = await storage.getActiveThreads();
    if (threads.isEmpty) {
      return const <ThreadMatch>[];
    }

    final ambient = await context.captureContext();
    return matching.rankThreads(
      threads: threads,
      context: _applySignalSettings(ambient, settings),
      limit: limit,
    );
  }

  /// Resurfaces at most one thread, if it clears the sensitivity threshold.
  ///
  /// Returns the match that was surfaced, or `null` when nothing qualified.
  Future<ThreadMatch?> checkAndResurface({
    required AppSettings settings,
    DateTime? now,
  }) async {
    final moment = now ?? DateTime.now();
    if (settings.isQuietAt(moment)) {
      return null;
    }

    final matches = await findRelevant(settings: settings);
    final startOfDay = DateTime(moment.year, moment.month, moment.day);

    for (final match in matches) {
      // Sorted best first, so the first thread under the threshold ends it.
      if (match.score < settings.matchSensitivity) {
        break;
      }

      final lastSurfaced = match.thread.lastSurfaced;
      if (lastSurfaced != null && !lastSurfaced.isBefore(startOfDay)) {
        continue;
      }

      await notifications.showResurface(
        threadId: match.thread.id,
        snippet: match.thread.content,
      );
      await storage.updateThread(
        match.thread.copyWith(
          lastSurfaced: moment,
          surfaceCount: match.thread.surfaceCount + 1,
        ),
      );
      return match;
    }

    return null;
  }

  /// Marks threads with no interaction for `autoKillAfterDays` as inactive.
  ///
  /// The last interaction is the most recent surface, falling back to the
  /// capture date (opens and edits are not tracked yet). Data stays in the
  /// export; only `isActive` changes. Returns how many threads were put to
  /// rest.
  Future<int> autoKillStale({required bool enabled, DateTime? now}) async {
    if (!enabled) {
      return 0;
    }

    final moment = now ?? DateTime.now();
    final cutoff = moment.subtract(
      const Duration(days: AppSettings.autoKillAfterDays),
    );

    var killed = 0;
    for (final thread in await storage.getActiveThreads()) {
      final lastInteraction = thread.lastSurfaced ?? thread.createdAt;
      if (lastInteraction.isBefore(cutoff)) {
        await storage.updateThread(thread.copyWith(isActive: false));
        killed++;
      }
    }
    return killed;
  }

  /// Drops the context signals the user has switched off.
  static Map<String, dynamic> _applySignalSettings(
    Map<String, dynamic> context,
    AppSettings settings,
  ) {
    final filtered = Map<String, dynamic>.from(context);

    if (!settings.useTime) {
      filtered
        ..remove(ContextKeys.hour)
        ..remove(ContextKeys.weekday)
        ..remove(ContextKeys.isWeekend)
        ..remove(ContextKeys.timeZoneOffsetMinutes)
        ..remove(ContextKeys.timeZoneName);
    }
    if (!settings.useBattery) {
      filtered
        ..remove(ContextKeys.batteryLevel)
        ..remove(ContextKeys.batteryState);
    }
    if (!settings.useLocation) {
      filtered
        ..remove(ContextKeys.latitude)
        ..remove(ContextKeys.longitude)
        ..remove(ContextKeys.locationAccuracyMeters);
    }
    if (!settings.useDevice) {
      filtered
        ..remove(ContextKeys.deviceModel)
        ..remove(ContextKeys.platform);
    }

    return filtered;
  }
}
