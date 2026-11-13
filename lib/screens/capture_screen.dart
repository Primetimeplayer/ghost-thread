import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../models/ghost_thread.dart';
import '../providers/thread_providers.dart';

/// Captures a new thought and stores it locally.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  static const Duration _successPause = Duration(milliseconds: 700);

  final TextEditingController _controller = TextEditingController();
  bool _isSaving = false;
  bool _saved = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave => !_isSaving && !_saved && _controller.text.trim().isNotEmpty;

  Future<void> _save() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final context = await ref.read(contextServiceProvider).captureContext();
      final thread = GhostThread(
        id: const Uuid().v4(),
        content: content,
        createdAt: DateTime.now(),
        contextAtCreation: context,
        embedding: ref.read(embeddingServiceProvider).embed(content),
      );

      await ref.read(storageServiceProvider).saveThread(thread);
      ref.invalidate(activeThreadsProvider);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save thread. Please try again.'),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      _saved = true;
    });

    await Future<void>.delayed(_successPause);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, size: 20),
            SizedBox(width: 8),
            Text('Thread saved'),
          ],
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture')),
      body: _saved
          ? const _SavedCheck()
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        keyboardType: TextInputType.multiline,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'What is the thought you keep putting off?',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _canSave ? _save : null,
                      icon: _isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_isSaving ? 'Saving…' : 'Save Thread'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// A brief checkmark shown between saving and returning home.
class _SavedCheck extends StatelessWidget {
  const _SavedCheck();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.6 + value * 0.4, child: child),
          );
        },
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 48,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
