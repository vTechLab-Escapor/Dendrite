import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dendrite/features/ingest/ingest_models.dart';
import 'package:dendrite/features/ingest/ingest_service.dart';

const _atom = '''
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <id>http://arxiv.org/abs/1706.03762v5</id>
    <title>Attention Is All You Need</title>
    <summary>We propose the Transformer, a model architecture based solely on attention mechanisms, dispensing with recurrence and convolutions entirely.</summary>
    <author><name>Ashish Vaswani</name></author>
    <author><name>Noam Shazeer</name></author>
    <category term="cs.CL" />
    <category term="cs.LG" />
  </entry>
</feed>
''';

void main() {
  test('arXiv ingest builds overview prompt + 5 branch seeds', () async {
    final client = MockClient((req) async {
      expect(req.url.host, 'export.arxiv.org');
      expect(req.url.query, contains('1706.03762v5'));
      return http.Response(_atom, 200,
          headers: {'content-type': 'application/atom+xml'});
    });

    final svc = IngestService(client: client);
    final content = await svc.ingestUrl('https://arxiv.org/abs/1706.03762v5');

    expect(content.kind, SourceKind.arxiv);
    expect(content.title, 'Attention Is All You Need');
    expect(content.sourceUrl, 'https://arxiv.org/abs/1706.03762v5');
    expect(content.rootPrompt, contains('Attention Is All You Need'));
    expect(content.rootPrompt, contains('Ashish Vaswani, Noam Shazeer'));
    expect(content.rootPrompt, contains('cs.CL, cs.LG'));
    expect(content.rootPrompt, contains('dispensing with recurrence'));
    expect(content.seeds, hasLength(5));
    expect(content.seeds.first.title, 'Core contribution');
  });

  test('arXiv non-200 raises a user-facing IngestException', () async {
    final client = MockClient((req) async => http.Response('nope', 500));
    final svc = IngestService(client: client);
    expect(
      () => svc.ingestUrl('https://arxiv.org/abs/0000.00000'),
      throwsA(isA<IngestException>()),
    );
  });
}
