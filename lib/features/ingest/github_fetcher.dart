import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:dendrite/features/ingest/ingest_models.dart';
import 'package:dendrite/features/ingest/url_detector.dart';

/// Fetches a GitHub repository (description + README + file tree) or a single
/// file via the public REST/raw APIs, and shapes it into a root prompt plus
/// branch seeds. Unauthenticated (60 req/hr); a token can be added later.
class GithubFetcher {
  final http.Client _client;
  final String? token;
  GithubFetcher(this._client, {this.token});

  static const _maxReadme = 6000;
  static const _maxFile = 8000;

  // A token raises the API limit from 60/hr (unauthenticated) to 5000/hr —
  // needed for repo metadata/README/tree; the raw-file CDN needs no token.
  Map<String, String> get _apiHeaders => {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'Dendrite',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<IngestedContent> fetch(DetectedSource src) =>
      src.kind == SourceKind.githubFile ? _fetchFile(src) : _fetchRepo(src);

  Future<IngestedContent> _fetchRepo(DetectedSource src) async {
    final base = 'https://api.github.com/repos/${src.owner}/${src.repo}';
    final meta = await _get(Uri.parse(base), _apiHeaders);
    _guard(meta.statusCode, '${src.owner}/${src.repo}');
    final m = jsonDecode(meta.body) as Map<String, dynamic>;

    final desc = (m['description'] as String?)?.trim() ?? '';
    final lang = (m['language'] as String?) ?? '—';
    final stars = m['stargazers_count'] ?? 0;
    final branch = (m['default_branch'] as String?) ?? 'main';

    // README (best-effort).
    String readme = '';
    final rd = await _get(Uri.parse('$base/readme'), _apiHeaders);
    if (rd.statusCode == 200) {
      final j = jsonDecode(rd.body) as Map<String, dynamic>;
      final encoded = (j['content'] as String?) ?? '';
      try {
        readme = utf8.decode(base64.decode(encoded.replaceAll('\n', '')));
      } catch (_) {/* binary/odd README — skip */}
    }
    if (readme.length > _maxReadme) {
      readme = '${readme.substring(0, _maxReadme)}\n…(truncated)';
    }

    // Top-level structure (best-effort).
    String tree = '';
    final tr = await _get(
        Uri.parse('$base/git/trees/$branch?recursive=0'), _apiHeaders);
    if (tr.statusCode == 200) {
      final j = jsonDecode(tr.body) as Map<String, dynamic>;
      final entries = (j['tree'] as List?) ?? const [];
      tree = entries.take(40).map((e) {
        final isDir = e['type'] == 'tree';
        return '${isDir ? '📁' : '📄'} ${e['path']}';
      }).join('\n');
    }

    final url = 'https://github.com/${src.owner}/${src.repo}';
    final root = StringBuffer()
      ..writeln(
          "I'm analyzing this GitHub repository. Give me a high-level overview of what it does and how it's built.")
      ..writeln()
      ..writeln('Repository: ${src.owner}/${src.repo}')
      ..writeln('Description: ${desc.isEmpty ? '(none)' : desc}')
      ..writeln('Primary language: $lang · Stars: $stars · Default branch: $branch')
      ..writeln('Link: $url');
    if (readme.isNotEmpty) root..writeln()..writeln('README:')..writeln(readme);
    if (tree.isNotEmpty) {
      root..writeln()..writeln('Top-level structure:')..writeln(tree);
    }

    return IngestedContent(
      kind: SourceKind.githubRepo,
      sourceUrl: url,
      title: '${src.owner}/${src.repo}',
      rootPrompt: root.toString().trim(),
      seeds: const [
        BranchSeed('Purpose',
            'In plain terms, what problem does this project solve and who is it for?'),
        BranchSeed('Architecture',
            'How is the codebase organized? Walk through the main directories and their responsibilities.'),
        BranchSeed('Key components',
            'What are the most important modules or files, and what does each one do?'),
        BranchSeed('Getting started',
            'How do I set up, build, and run this project locally? Summarize the steps.'),
        BranchSeed('Tech stack',
            'What languages, frameworks, and notable dependencies does it rely on?'),
      ],
    );
  }

  Future<IngestedContent> _fetchFile(DetectedSource src) async {
    final raw =
        'https://raw.githubusercontent.com/${src.owner}/${src.repo}/${src.ref}/${src.path}';
    final res = await _get(Uri.parse(raw), const {'User-Agent': 'Dendrite'});
    if (res.statusCode == 404) {
      throw IngestException('File not found: ${src.path}');
    }
    if (res.statusCode != 200) {
      throw IngestException('Could not fetch file (${res.statusCode})');
    }
    var body = res.body;
    if (body.length > _maxFile) {
      body = '${body.substring(0, _maxFile)}\n…(truncated)';
    }

    final fileName = src.path!.split('/').last;
    final url =
        'https://github.com/${src.owner}/${src.repo}/blob/${src.ref}/${src.path}';
    final root = StringBuffer()
      ..writeln(
          "I'm analyzing this source file from GitHub. Explain what it does at a high level.")
      ..writeln()
      ..writeln('File: ${src.path} (${src.owner}/${src.repo})')
      ..writeln('Link: $url')
      ..writeln()
      ..writeln('```')
      ..writeln(body)
      ..writeln('```');

    return IngestedContent(
      kind: SourceKind.githubFile,
      sourceUrl: url,
      title: fileName,
      rootPrompt: root.toString().trim(),
      seeds: const [
        BranchSeed('Responsibility',
            'What is the single main responsibility of this file, and where does it fit in the project?'),
        BranchSeed('Walkthrough',
            'Walk through the key functions/classes in this file and what each does.'),
        BranchSeed('Dependencies',
            'What does this file import or depend on, and what likely depends on it?'),
        BranchSeed('Risks & improvements',
            'What bugs, edge cases, or improvements stand out in this code?'),
      ],
    );
  }

  Future<http.Response> _get(Uri uri, Map<String, String> headers) async {
    try {
      return await _client.get(uri, headers: headers);
    } catch (e) {
      throw IngestException('Could not reach GitHub: $e');
    }
  }

  void _guard(int status, String what) {
    if (status == 404) throw IngestException('Repository $what not found');
    if (status == 403) {
      throw IngestException('GitHub API rate limit reached — try again later');
    }
    if (status != 200) throw IngestException('GitHub API returned $status');
  }
}
