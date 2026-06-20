import 'package:http/http.dart' as http;

import 'package:dendrite/features/ingest/arxiv_fetcher.dart';
import 'package:dendrite/features/ingest/github_fetcher.dart';
import 'package:dendrite/features/ingest/ingest_models.dart';
import 'package:dendrite/features/ingest/url_detector.dart';

/// Entry point for content ingestion: detect a supported URL, then fetch it
/// into an [IngestedContent] (root prompt + branch seeds). The chat layer turns
/// that into a real branched conversation. [http.Client] is injectable for tests.
class IngestService {
  final http.Client _client;
  final bool _ownsClient;
  final String? githubToken;

  IngestService({http.Client? client, this.githubToken})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  /// Parse [input] into a recognized source, or null if unsupported.
  DetectedSource? detect(String input) => UrlDetector.detect(input);

  Future<IngestedContent> ingest(DetectedSource src) {
    switch (src.kind) {
      case SourceKind.arxiv:
        return ArxivFetcher(_client).fetch(src);
      case SourceKind.githubRepo:
      case SourceKind.githubFile:
        return GithubFetcher(_client, token: githubToken).fetch(src);
      case SourceKind.unknown:
        throw IngestException('Unsupported link');
    }
  }

  /// Convenience: detect + ingest in one call. Throws [IngestException] if the
  /// link isn't recognized.
  Future<IngestedContent> ingestUrl(String input) {
    final src = detect(input);
    if (src == null) {
      throw IngestException('Not a recognized arXiv or GitHub link');
    }
    return ingest(src);
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
