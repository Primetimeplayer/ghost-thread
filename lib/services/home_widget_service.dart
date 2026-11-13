import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/ghost_thread.dart';

/// Pushes the thread to show on the home-screen widget.
///
/// Rendering lives in the native widget (Android provider, iOS WidgetKit
/// extension). The app only writes the snippet and id, and reads the tap URI.
class HomeWidgetService {
  const HomeWidgetService();

  static const String snippetKey = 'ghost_thread_snippet';
  static const String threadIdKey = 'ghost_thread_id';
  static const String androidProvider =
      'com.ghostthread.ghost_thread.GhostThreadWidgetProvider';
  static const String iosWidgetName = 'GhostThreadWidget';
  static const String emptySnippet = 'No unfinished thoughts';

  /// Updates the widget with the most recently surfaced active thread.
  Future<void> refresh({required List<GhostThread> activeThreads}) async {
    if (kIsWeb) {
      return;
    }

    try {
      final thread = _pick(activeThreads);
      await HomeWidget.saveWidgetData<String>(
        snippetKey,
        thread == null ? emptySnippet : _shorten(thread.content),
      );
      await HomeWidget.saveWidgetData<String>(threadIdKey, thread?.id ?? '');
      await HomeWidget.updateWidget(
        androidName: androidProvider,
        iOSName: iosWidgetName,
      );
    } on Object catch (error) {
      debugPrint('Home widget update skipped: $error');
    }
  }

  /// Reads a `ghostthread://thread/<id>` tap from the widget.
  static String? threadIdFromUri(Uri? uri) {
    if (uri == null || uri.scheme != 'ghostthread' || uri.host != 'thread') {
      return null;
    }
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    return segments.isEmpty ? null : segments.first;
  }

  static GhostThread? _pick(List<GhostThread> threads) {
    if (threads.isEmpty) {
      return null;
    }

    final sorted = List<GhostThread>.of(threads)
      ..sort((a, b) {
        final aTime = a.lastSurfaced ?? a.createdAt;
        final bTime = b.lastSurfaced ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
    return sorted.first;
  }

  static String _shorten(String content) {
    final collapsed = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= 160) {
      return collapsed;
    }
    return '${collapsed.substring(0, 159)}…';
  }
}
