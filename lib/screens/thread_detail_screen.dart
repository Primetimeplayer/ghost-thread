import 'package:material_ui/material_ui.dart';

/// A single thread. Scaffolding only.
class ThreadDetailScreen extends StatelessWidget {
  const ThreadDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thread')),
      body: const Center(child: Text('Thread detail')),
    );
  }
}
