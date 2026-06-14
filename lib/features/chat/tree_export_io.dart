import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Mobile/desktop: write the Markdown to the app documents directory and return
/// the absolute path so the UI can surface it (and the user can share it).
Future<String> saveTreeMarkdown(String filename, String content) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, filename));
  await file.writeAsString(content);
  return file.path;
}
