import 'package:dendrite/features/ingest/ingest_models.dart';

/// A parsed, recognized source URL with the bits each fetcher needs.
class DetectedSource {
  final SourceKind kind;
  final Uri uri;

  // arXiv
  final String? arxivId;

  // GitHub
  final String? owner;
  final String? repo;
  final String? ref; // branch / tag / sha
  final String? path; // file or subdir path

  const DetectedSource({
    required this.kind,
    required this.uri,
    this.arxivId,
    this.owner,
    this.repo,
    this.ref,
    this.path,
  });
}

/// Recognizes arXiv and GitHub links (with or without a scheme) and extracts
/// the identifiers needed to fetch them. Returns null for anything else.
class UrlDetector {
  static final _dotGit = RegExp(r'\.git$');
  static final _dotPdf = RegExp(r'\.pdf$');

  static DetectedSource? detect(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    Uri? uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    // Tolerate bare hosts like "github.com/a/b" (no scheme).
    if (uri.host.isEmpty) {
      uri = Uri.tryParse('https://$trimmed');
      if (uri == null || uri.host.isEmpty) return null;
    }

    final host = uri.host.toLowerCase();
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    if (host.contains('arxiv.org')) {
      String? id;
      final i = segs.indexWhere((s) => s == 'abs' || s == 'pdf');
      if (i != -1 && i + 1 < segs.length) {
        id = segs.sublist(i + 1).join('/');
      } else if (segs.isNotEmpty) {
        id = segs.join('/');
      }
      if (id != null && id.isNotEmpty) {
        id = id.replaceAll(_dotPdf, '');
        return DetectedSource(kind: SourceKind.arxiv, uri: uri, arxivId: id);
      }
      return null;
    }

    if (host == 'github.com' || host == 'www.github.com') {
      if (segs.length < 2) return null;
      final owner = segs[0];
      final repo = segs[1].replaceAll(_dotGit, '');
      if (segs.length >= 5 && (segs[2] == 'blob' || segs[2] == 'raw')) {
        return DetectedSource(
          kind: SourceKind.githubFile,
          uri: uri,
          owner: owner,
          repo: repo,
          ref: segs[3],
          path: segs.sublist(4).join('/'),
        );
      }
      String? ref;
      String? path;
      if (segs.length >= 4 && segs[2] == 'tree') {
        ref = segs[3];
        if (segs.length > 4) path = segs.sublist(4).join('/');
      }
      return DetectedSource(
        kind: SourceKind.githubRepo,
        uri: uri,
        owner: owner,
        repo: repo,
        ref: ref,
        path: path,
      );
    }

    if (host == 'raw.githubusercontent.com' && segs.length >= 4) {
      return DetectedSource(
        kind: SourceKind.githubFile,
        uri: uri,
        owner: segs[0],
        repo: segs[1],
        ref: segs[2],
        path: segs.sublist(3).join('/'),
      );
    }

    return null;
  }
}
