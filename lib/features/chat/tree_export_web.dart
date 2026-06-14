// ignore: deprecated_member_use
import 'dart:html' as html;

/// Web: trigger a browser download of the Markdown file. Returns the filename
/// (there is no filesystem path in the browser sandbox).
Future<String> saveTreeMarkdown(String filename, String content) async {
  final bytes = html.Blob([content], 'text/markdown;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(bytes);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return filename;
}
