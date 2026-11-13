import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes [json] next to the app documents and returns the file path.
Future<String> writeExportFile(String json) async {
  final directory = await getApplicationDocumentsDirectory();
  final stamp = DateTime.now().toIso8601String().replaceAll(
    RegExp(r'[:.]'),
    '-',
  );
  final file = File('${directory.path}/ghost_threads_export_$stamp.json');
  await file.writeAsString(json);
  return file.path;
}
