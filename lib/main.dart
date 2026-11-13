import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'providers/thread_providers.dart';
import 'screens/home_screen.dart';
import 'services/embedding_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.init();

  // One-time, silent fix-up for threads captured before embeddings existed.
  // Failures here must never block startup.
  try {
    await storage.backfillEmbeddings(const EmbeddingService());
  } on Object catch (error) {
    debugPrint('Embedding backfill skipped: $error');
  }

  runApp(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
      child: const GhostThreadApp(),
    ),
  );
}

/// Root widget for GhostThread.
class GhostThreadApp extends StatelessWidget {
  const GhostThreadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GhostThread',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF6750A4)),
      home: const HomeScreen(),
    );
  }
}
