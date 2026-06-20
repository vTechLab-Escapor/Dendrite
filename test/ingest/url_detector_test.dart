import 'package:flutter_test/flutter_test.dart';
import 'package:dendrite/features/ingest/ingest_models.dart';
import 'package:dendrite/features/ingest/url_detector.dart';

void main() {
  group('UrlDetector.detect', () {
    test('arXiv /abs link with version', () {
      final s = UrlDetector.detect('https://arxiv.org/abs/1706.03762v5')!;
      expect(s.kind, SourceKind.arxiv);
      expect(s.arxivId, '1706.03762v5');
    });

    test('arXiv /pdf link strips .pdf', () {
      final s = UrlDetector.detect('https://arxiv.org/pdf/2301.12345.pdf')!;
      expect(s.kind, SourceKind.arxiv);
      expect(s.arxivId, '2301.12345');
    });

    test('arXiv old-style id with subject class', () {
      final s = UrlDetector.detect('arxiv.org/abs/math/0211159')!;
      expect(s.kind, SourceKind.arxiv);
      expect(s.arxivId, 'math/0211159');
    });

    test('GitHub repo root (no scheme, trailing .git)', () {
      final s = UrlDetector.detect('github.com/flutter/flutter.git')!;
      expect(s.kind, SourceKind.githubRepo);
      expect(s.owner, 'flutter');
      expect(s.repo, 'flutter');
    });

    test('GitHub tree subdir is still a repo', () {
      final s =
          UrlDetector.detect('https://github.com/owner/repo/tree/dev/lib/src')!;
      expect(s.kind, SourceKind.githubRepo);
      expect(s.ref, 'dev');
      expect(s.path, 'lib/src');
    });

    test('GitHub blob is a file', () {
      final s = UrlDetector.detect(
          'https://github.com/owner/repo/blob/main/lib/app.dart')!;
      expect(s.kind, SourceKind.githubFile);
      expect(s.ref, 'main');
      expect(s.path, 'lib/app.dart');
    });

    test('raw.githubusercontent is a file', () {
      final s = UrlDetector.detect(
          'https://raw.githubusercontent.com/owner/repo/main/README.md')!;
      expect(s.kind, SourceKind.githubFile);
      expect(s.path, 'README.md');
    });

    test('unrelated URLs return null', () {
      expect(UrlDetector.detect('https://example.com/foo'), isNull);
      expect(UrlDetector.detect('not a url at all '), isNull);
      expect(UrlDetector.detect(''), isNull);
    });
  });
}
