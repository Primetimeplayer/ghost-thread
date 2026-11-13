import 'package:material_ui/material_ui.dart';

/// Thread list. Scaffolding only.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GhostThread')),
      body: const Center(child: Text('Home')),
    );
  }
}
