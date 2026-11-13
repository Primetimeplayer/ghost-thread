import 'dart:io';

import 'package:path_provider/path_provider.dart';

const String _prefix = 'ghost_backup_';
const String _extension = '.ghostthread';

/// Writes an encrypted backup next to the app documents.
Future<String> writeBackupFile(String contents) async {
  final directory = await getApplicationDocumentsDirectory();
  final stamp = DateTime.now().toIso8601String().replaceAll(
    RegExp(r'[:.]'),
    '-',
  );
  final file = File('${directory.path}/$_prefix$stamp$_extension');
  await file.writeAsString(contents);
  return file.path;
}

Future<String> readBackupFile(String path) {
  return File(path).readAsString();
}

/// Backup files in the app documents directory, newest first.
Future<List<String>> listBackupFiles() async {
  final directory = await getApplicationDocumentsDirectory();
  final paths = <String>[];

  await for (final entity in directory.list()) {
    if (entity is! File) {
      continue;
    }
    final name = entity.uri.pathSegments.last;
    if (name.startsWith(_prefix) && name.endsWith(_extension)) {
      paths.add(entity.path);
    }
  }

  paths.sort((a, b) => b.compareTo(a));
  return paths;
}
