/// Data shapes for the content-ingestion layer: a URL is fetched and turned into
/// a [IngestedContent] — one root prompt (the trunk question, seeded with the
/// fetched text) plus a list of [BranchSeed]s that become branches off it.
library;

enum SourceKind { arxiv, githubRepo, githubFile, unknown }

/// One suggested branch off the root overview: a short [title] (used as the
/// branch's selected-context label) and the [prompt] sent to the model.
class BranchSeed {
  final String title;
  final String prompt;
  const BranchSeed(this.title, this.prompt);
}

/// The normalized result of ingesting a source, ready to drive the chat tree.
class IngestedContent {
  final SourceKind kind;
  final String sourceUrl;
  final String title;
  final String rootPrompt;
  final List<BranchSeed> seeds;
  const IngestedContent({
    required this.kind,
    required this.sourceUrl,
    required this.title,
    required this.rootPrompt,
    required this.seeds,
  });
}

/// Thrown when a source can't be fetched or parsed; [message] is user-facing.
class IngestException implements Exception {
  final String message;
  IngestException(this.message);
  @override
  String toString() => message;
}
