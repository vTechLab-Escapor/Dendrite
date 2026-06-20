import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dendrite/features/ingest/ingest_models.dart';
import 'package:dendrite/features/ingest/ingest_service.dart';

void main() {
  test('GitHub repo ingest pulls description, README and tree', () async {
    final client = MockClient((req) async {
      final u = req.url.toString();
      if (u == 'https://api.github.com/repos/octo/widget') {
        return http.Response(
            jsonEncode({
              'description': 'A tiny widget library.',
              'language': 'Dart',
              'stargazers_count': 42,
              'default_branch': 'main',
            }),
            200);
      }
      if (u == 'https://api.github.com/repos/octo/widget/readme') {
        return http.Response(
            jsonEncode({
              'content': base64.encode(utf8.encode('# Widget\nDoes widget things.')),
            }),
            200);
      }
      if (u.startsWith('https://api.github.com/repos/octo/widget/git/trees/')) {
        return http.Response(
            jsonEncode({
              'tree': [
                {'path': 'lib', 'type': 'tree'},
                {'path': 'README.md', 'type': 'blob'},
              ],
            }),
            200);
      }
      return http.Response('not found', 404);
    });

    final svc = IngestService(client: client);
    final content = await svc.ingestUrl('https://github.com/octo/widget');

    expect(content.kind, SourceKind.githubRepo);
    expect(content.title, 'octo/widget');
    expect(content.rootPrompt, contains('A tiny widget library.'));
    expect(content.rootPrompt, contains('Does widget things.'));
    expect(content.rootPrompt, contains('📁 lib'));
    expect(content.rootPrompt, contains('📄 README.md'));
    expect(content.seeds, hasLength(5));
  });

  test('GitHub file ingest fetches raw content', () async {
    final client = MockClient((req) async {
      if (req.url.host == 'raw.githubusercontent.com') {
        return http.Response('void main() {}\n', 200);
      }
      return http.Response('', 404);
    });

    final svc = IngestService(client: client);
    final content = await svc
        .ingestUrl('https://github.com/octo/widget/blob/main/lib/main.dart');

    expect(content.kind, SourceKind.githubFile);
    expect(content.title, 'main.dart');
    expect(content.rootPrompt, contains('void main() {}'));
    expect(content.seeds, hasLength(4));
  });

  test('missing repo raises IngestException', () async {
    final client = MockClient((req) async => http.Response('Not Found', 404));
    final svc = IngestService(client: client);
    expect(
      () => svc.ingestUrl('https://github.com/no/such'),
      throwsA(isA<IngestException>()),
    );
  });
}
