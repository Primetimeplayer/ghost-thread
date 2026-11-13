const String _unavailable =
    'Encrypted backups are not available in the browser yet.';

Future<String> writeBackupFile(String contents) async {
  throw UnsupportedError(_unavailable);
}

Future<String> readBackupFile(String path) async {
  throw UnsupportedError(_unavailable);
}

Future<List<String>> listBackupFiles() async {
  throw UnsupportedError(_unavailable);
}
