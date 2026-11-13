import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../models/ghost_thread.dart';
import '../providers/service_providers.dart';
import '../providers/thread_providers.dart';
import '../services/crypto_service.dart';

/// Asks for a passphrase, optionally with a confirmation field.
Future<String?> askPassphraseDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
  bool confirm = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _PassphraseDialog(
      title: title,
      message: message,
      actionLabel: actionLabel,
      confirm: confirm,
    ),
  );
}

/// Shares [thread] encrypted with a passphrase via the system share sheet.
Future<void> showShareThreadDialog(
  BuildContext context,
  WidgetRef ref,
  GhostThread thread,
) async {
  final passphrase = await askPassphraseDialog(
    context,
    title: 'Share privately',
    message:
        'The thought is encrypted on this device with a passphrase you choose. '
        'Send that passphrase to the recipient separately — without it the '
        'payload cannot be read.',
    actionLabel: 'Create & share',
    confirm: true,
  );
  if (passphrase == null || !context.mounted) {
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(shareServiceProvider)
        .shareThread(thread: thread, passphrase: passphrase);
  } on CryptoException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  } on Object {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not create the private share.')),
    );
  }
}

/// Imports an encrypted thread payload pasted by the user.
Future<void> showImportThreadDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final payload = await _askText(
    context,
    title: 'Import private thread',
    message: 'Paste the encrypted GhostThread payload you received.',
    actionLabel: 'Next',
  );
  if (payload == null || !context.mounted) {
    return;
  }

  final passphrase = await askPassphraseDialog(
    context,
    title: 'Passphrase',
    message: 'Enter the passphrase this thought was shared with.',
    actionLabel: 'Import',
  );
  if (passphrase == null || !context.mounted) {
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  try {
    final thread = await ref
        .read(shareServiceProvider)
        .importPayload(payload, passphrase);
    await ref.read(storageServiceProvider).saveThread(thread);
    ref.invalidate(activeThreadsProvider);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.lock_open, size: 20),
            SizedBox(width: 8),
            Text('Private thread imported'),
          ],
        ),
      ),
    );
  } on CryptoException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  } on Object {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not import this thread.')),
    );
  }
}

/// Merge keeps existing threads; replace clears local data first.
Future<bool?> askRestoreModeDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Restore backup'),
      content: const Text(
        'Merge adds threads that are missing and leaves your current threads '
        'alone. Replace removes every thread on this device first.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Merge'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Replace'),
        ),
      ],
    ),
  );
}

Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
}) {
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'GHOSTTHREAD-PRIVATE:…',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isEmpty) {
              return;
            }
            Navigator.of(dialogContext).pop(value);
          },
          child: Text(actionLabel),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.confirm,
  });

  final String title;
  final String message;
  final String actionLabel;
  final bool confirm;

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final TextEditingController _passphrase = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _passphrase.text;
    if (value.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    if (widget.confirm && value != _confirmation.text) {
      setState(() => _error = 'Passphrases do not match.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            TextField(
              controller: _passphrase,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Passphrase',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.confirm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirmation,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm passphrase',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}
