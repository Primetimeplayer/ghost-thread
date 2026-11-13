import 'package:material_ui/material_ui.dart';

/// Capture a new thought. Scaffolding only.
class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture')),
      body: const Center(child: Text('Capture a thought')),
    );
  }
}
