/// Browser fallback: there is no app documents directory on web yet.
Future<String> writeExportFile(String json) async {
  throw UnsupportedError('JSON export is not available in the browser yet.');
}
