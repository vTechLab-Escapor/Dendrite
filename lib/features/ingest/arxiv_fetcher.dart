import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'package:dendrite/features/ingest/ingest_models.dart';
import 'package:dendrite/features/ingest/url_detector.dart';

/// Fetches paper metadata from the arXiv Atom API and shapes it into a root
/// overview prompt plus analytical branch seeds. No PDF parsing — the abstract
/// is enough context for the model to anchor a multi-branch analysis.
class ArxivFetcher {
  final http.Client _client;
  ArxivFetcher(this._client);

  static const _seeds = [
    BranchSeed('Core contribution',
        'What is the central contribution of this paper, and what makes it novel relative to prior work?'),
    BranchSeed('Method',
        'Explain the proposed method/approach in detail, step by step, including the key intuition behind it.'),
    BranchSeed('Experiments & results',
        'What experiments were run and what do the results show? Highlight the most important metrics and comparisons.'),
    BranchSeed('Limitations',
        'What are the limitations, assumptions, and likely failure modes of this work?'),
    BranchSeed('Impact & future work',
        'What are the broader implications, applications, and promising future directions?'),
  ];

  Future<IngestedContent> fetch(DetectedSource src) async {
    final api = Uri.parse(
        'https://export.arxiv.org/api/query?id_list=${src.arxivId}');
    late final http.Response res;
    try {
      res = await _client.get(api);
    } catch (e) {
      throw IngestException('Could not reach arXiv: $e');
    }
    if (res.statusCode != 200) {
      throw IngestException('arXiv API returned ${res.statusCode}');
    }

    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(res.body);
    } on XmlException {
      throw IngestException('Unexpected response from arXiv');
    }

    final entry = _first(doc.findAllElements('entry'));
    // arXiv returns an <entry> with a generic title for unknown ids.
    if (entry == null) {
      throw IngestException('Paper ${src.arxivId} not found on arXiv');
    }

    String text(String name) =>
        _first(entry.findElements(name))?.innerText.trim().replaceAll(
            RegExp(r'\s+'), ' ') ??
        '';

    final title = text('title');
    final summary = text('summary');
    if (title.isEmpty && summary.isEmpty) {
      throw IngestException('Paper ${src.arxivId} not found on arXiv');
    }
    final authors = entry
        .findElements('author')
        .map((a) => _first(a.findElements('name'))?.innerText.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final cats = entry
        .findElements('category')
        .map((c) => c.getAttribute('term') ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    final url = 'https://arxiv.org/abs/${src.arxivId}';
    final authorLine = authors.isEmpty
        ? '(unknown)'
        : '${authors.take(8).join(', ')}${authors.length > 8 ? ' et al.' : ''}';

    final root = StringBuffer()
      ..writeln(
          "I'm analyzing this arXiv paper. Give me a concise, high-level overview of what it is and why it matters.")
      ..writeln()
      ..writeln('Title: $title')
      ..writeln('Authors: $authorLine')
      ..writeln('Categories: ${cats.join(', ')}')
      ..writeln('Link: $url')
      ..writeln()
      ..writeln('Abstract:')
      ..writeln(summary);

    return IngestedContent(
      kind: SourceKind.arxiv,
      sourceUrl: url,
      title: title.isEmpty ? src.arxivId! : title,
      rootPrompt: root.toString().trim(),
      seeds: _seeds,
    );
  }

  static XmlElement? _first(Iterable<XmlElement> it) =>
      it.isEmpty ? null : it.first;
}
