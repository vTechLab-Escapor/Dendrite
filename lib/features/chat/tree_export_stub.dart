/// Platform-agnostic entry point for saving an exported Markdown file.
///
/// The concrete implementation is swapped in at compile time via conditional
/// import (see [ChatCubit]): [tree_export_io.dart] on mobile/desktop,
/// [tree_export_web.dart] on web. This stub only exists so the import resolves
/// on platforms that match neither library.
Future<String> saveTreeMarkdown(String filename, String content) async {
  throw UnsupportedError('Markdown export is not supported on this platform');
}
