import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'models/app_settings.dart';
import 'providers/settings_provider.dart';
import 'providers/thread_providers.dart';
import 'screens/home_screen.dart';
import 'screens/thread_detail_screen.dart';
import 'services/embedding_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/storage_service.dart';
import 'widgets/resurface_watcher.dart';

/// Used for navigation from notification taps, which happen outside the tree.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.init();
  final settings = await SettingsService.init();

  // One-time, silent fix-up for threads captured before embeddings existed.
  // Failures here must never block startup.
  try {
    await storage.backfillEmbeddings(const EmbeddingService());
  } on Object catch (error) {
    debugPrint('Embedding backfill skipped: $error');
  }

  final notifications = NotificationService.instance;
  await notifications.init(onThreadTap: _openThread);

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        settingsServiceProvider.overrideWithValue(settings),
      ],
      child: const GhostThreadApp(),
    ),
  );

  final launchThreadId = await notifications.launchPayload();
  if (launchThreadId != null) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _openThread(launchThreadId),
    );
  }
}

void _openThread(String threadId) {
  appNavigatorKey.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => ThreadDetailScreen(threadId: threadId),
    ),
  );
}

/// Root widget for GhostThread.
class GhostThreadApp extends ConsumerWidget {
  const GhostThreadApp({super.key});

  static const Color _seedColor = Color(0xFF6750A4);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      settingsProvider.select((settings) => settings.themeMode),
    );

    return MaterialApp(
      title: 'GhostThread',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      home: const ResurfaceWatcher(child: HomeScreen()),
    );
  }
}
