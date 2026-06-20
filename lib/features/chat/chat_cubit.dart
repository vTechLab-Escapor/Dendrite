import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:dendrite/core/db/database.dart';
import 'package:dendrite/core/agent/agent_engine.dart';
import 'package:dendrite/core/models/api_config.dart';
import 'package:dendrite/core/utils/id_generator.dart';
import 'package:dendrite/features/chat/chat_repository.dart';
import 'package:dendrite/features/chat/chat_tree.dart';
import 'package:dendrite/features/chat/tree_export_stub.dart'
    if (dart.library.io) 'package:dendrite/features/chat/tree_export_io.dart'
    if (dart.library.html) 'package:dendrite/features/chat/tree_export_web.dart';
import 'package:dendrite/features/chat/chat_state.dart';
import 'package:dendrite/features/ingest/ingest_models.dart';
import 'package:dendrite/features/ingest/ingest_service.dart';
import 'package:dendrite/features/ingest/url_detector.dart';
import 'package:dendrite/features/settings/settings_repository.dart';

/// Owns all chat data state, persistence and the AI streaming lifecycle.
class ChatCubit extends Cubit<ChatState> {
  late final AppDatabase _db;
  late final ChatRepository _chatRepo;
  late final AgentEngine _agentEngine;
  final SettingsRepository _settingsRepo;
  final IngestService _ingestService;

  StreamSubscription<String>? _streamSubscription;
  Completer<void>? _streamCompleter;

  // One-off, already-composed messages for the UI to surface as toasts.
  final StreamController<String> _toastController =
      StreamController<String>.broadcast();
  Stream<String> get toasts => _toastController.stream;

  ChatCubit({
    AppDatabase? db,
    SettingsRepository? settingsRepo,
    IngestService? ingestService,
  })  : _settingsRepo = settingsRepo ?? SettingsRepository(),
        _ingestService = ingestService ??
            IngestService(
              githubToken:
                  const String.fromEnvironment('DENDRITE_GITHUB_TOKEN').isEmpty
                      ? null
                      : const String.fromEnvironment('DENDRITE_GITHUB_TOKEN'),
            ),
        super(const ChatState()) {
    _db = db ?? AppDatabase();
    _chatRepo = ChatRepository(_db);
    _agentEngine = AgentEngine(db: _db);
  }

  Future<void> init() async {
    final cloud = await _settingsRepo.load();
    final edge = await _settingsRepo.loadEdge(state.localConfig, state.backendMode);
    var local = edge.config;
    var mode = edge.mode;

    // E2E / local-MNN override: --dart-define=DENDRITE_BASE_URL=... points the
    // EDGE backend at the local MNN server and selects edge mode.
    const overrideUrl = String.fromEnvironment('DENDRITE_BASE_URL');
    if (overrideUrl.isNotEmpty) {
      local = local.copyWith(
        provider: 'mnn',
        baseUrl: overrideUrl,
        modelName: const String.fromEnvironment('DENDRITE_MODEL',
            defaultValue: 'mnn-local'),
        apiKey: const String.fromEnvironment('DENDRITE_API_KEY',
            defaultValue: 'sk-local'),
      );
      mode = BackendMode.edge;
    }
    if (isClosed) return;
    emit(state.copyWith(
        apiConfig: cloud, localConfig: local, backendMode: mode));
    await loadLineage();
    if (isClosed) return;
    emit(state.copyWith(initialized: true));
  }

  /// Update the CLOUD provider config.
  Future<void> updateConfig(ApiConfig config) async {
    emit(state.copyWith(apiConfig: config));
    await _settingsRepo.save(config);
  }

  /// Update the EDGE (local MNN) config.
  Future<void> updateLocalConfig(ApiConfig config) async {
    emit(state.copyWith(localConfig: config));
    await _settingsRepo.saveEdge(config, state.backendMode);
  }

  /// Switch the default backend (edge ↔ cloud) for new questions.
  Future<void> setBackendMode(BackendMode mode) async {
    emit(state.copyWith(backendMode: mode));
    await _settingsRepo.saveEdge(state.localConfig, mode);
  }

  Future<void> loadLineage() async {
    final chatNodes = await _chatRepo.nodesInChat(state.currentChatId);
    final leafId = ChatTree.resolveActiveLeaf(chatNodes, state.activeNodeId);
    final lineage =
        leafId != null ? await _chatRepo.ancestors(leafId) : <Message>[];
    if (isClosed) return;
    emit(state.copyWith(
      allNodesInChat: chatNodes,
      currentLineage: lineage,
      activeNodeId: leafId,
    ));
  }

  /// Distinct chat sessions for the history drawer.
  Future<List<MapEntry<String, String>>> chatSessions() =>
      _chatRepo.chatSessions();

  // --- Navigation ---

  Future<void> selectNode(String nodeId) async {
    emit(state.copyWith(activeNodeId: nodeId));
    await loadLineage();
  }

  Future<void> openBranch(String deepestId) async {
    final history = state.activeNodeId != null
        ? [...state.branchHistory, state.activeNodeId!]
        : state.branchHistory;
    emit(state.copyWith(branchHistory: history, activeNodeId: deepestId));
    await loadLineage();
  }

  Future<void> switchChat(String chatId) async {
    emit(state.copyWith(
        currentChatId: chatId, activeNodeId: null, branchHistory: []));
    await loadLineage();
  }

  Future<void> openSearchResult(String chatId, String nodeId) async {
    emit(state.copyWith(
        currentChatId: chatId, activeNodeId: nodeId, isSearching: false));
    await loadLineage();
  }

  Future<void> newChat() async {
    emit(state.copyWith(
      currentChatId: 'chat_${DateTime.now().millisecondsSinceEpoch}',
      activeNodeId: null,
      branchHistory: [],
      currentLineage: [],
    ));
    await loadLineage();
  }

  Future<void> returnToParentBranch() async {
    if (state.branchHistory.isNotEmpty) {
      final history = [...state.branchHistory];
      final prevId = history.removeLast();
      emit(state.copyWith(branchHistory: history, activeNodeId: prevId));
      await loadLineage();
    } else {
      if (state.currentLineage.isEmpty) return;
      final lastBranchMsg = state.currentLineage.reversed.firstWhere(
        (m) => m.associatedSelection != null,
        orElse: () => state.currentLineage.first,
      );
      emit(state.copyWith(activeNodeId: lastBranchMsg.parentId));
      await loadLineage();
    }
  }

  // --- Messaging ---

  Future<void> sendMessage(String finalContent, {BackendMode? backend}) async {
    final userMsgId = IdGenerator.generate();
    await _chatRepo.insertMessage(
      id: userMsgId,
      parentId: state.activeNodeId,
      chatId: state.currentChatId,
      role: 'user',
      content: finalContent,
    );
    emit(state.copyWith(activeNodeId: userMsgId));
    await loadLineage();
    await _triggerAICompletion(userMsgId, null, backend: backend);
  }

  /// Create a branch off [sourceNodeId]. [backend] lets a single branch run on a
  /// different engine than the trunk (per-branch routing); null = default mode.
  Future<void> createBranchQuestion(
      String sourceNodeId, String contextText, String question,
      {BackendMode? backend}) async {
    if (question.trim().isEmpty) return;

    final userMsgId = IdGenerator.generate();
    await _chatRepo.insertMessage(
      id: userMsgId,
      parentId: sourceNodeId,
      chatId: state.currentChatId,
      role: 'user',
      content: question,
      associatedSelection: contextText,
    );

    final history = state.activeNodeId != null
        ? [...state.branchHistory, state.activeNodeId!]
        : state.branchHistory;
    emit(state.copyWith(branchHistory: history, activeNodeId: userMsgId));
    await loadLineage();
    await _triggerAICompletion(userMsgId, contextText, backend: backend);
  }

  // --- Content ingestion (arXiv / GitHub URL -> branched analysis) ---

  /// Detect whether [input] is an ingestible arXiv/GitHub link, so the composer
  /// can offer "analyze" instead of sending it as a plain message. Null if not.
  DetectedSource? detectIngestable(String input) =>
      _ingestService.detect(input);

  /// Fetches an arXiv paper or GitHub repo/file from [url], seeds the trunk with
  /// an overview question, then fans one branch per analytical angle off that
  /// overview. The user lands back on the overview with the branches in place.
  ///
  /// Returns true if ingestion started; false if [url] wasn't a recognized link.
  Future<bool> ingestUrl(String url) async {
    final src = _ingestService.detect(url);
    if (src == null) {
      _toastController.add('Not a recognized arXiv or GitHub link');
      return false;
    }

    emit(state.copyWith(isIngesting: true));
    IngestedContent content;
    try {
      content = await _ingestService.ingest(src);
    } on IngestException catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(isIngesting: false));
      _toastController.add(e.message);
      return false;
    } catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(isIngesting: false));
      _toastController.add('Could not fetch source: ${_friendlyError(e)}');
      return false;
    }
    if (isClosed) return false;
    emit(state.copyWith(isIngesting: false));

    // Each analysis is its own knowledge tree — start a clean chat so the
    // overview is a true root (no parent) and branches fan off it.
    await newChat();

    // Trunk: the overview question, seeded with the fetched context.
    await sendMessage(content.rootPrompt);
    final rootAnswerId = state.activeNodeId;
    if (rootAnswerId == null) return true;

    // Fan out: one branch per analytical angle, all rooted at the overview.
    for (final seed in content.seeds) {
      if (isClosed) return true;
      await createBranchQuestion(rootAnswerId, seed.title, seed.prompt);
    }

    // Land the user on the overview with the branches fanned out beneath it.
    if (isClosed) return true;
    await selectNode(rootAnswerId);
    return true;
  }

  /// Stops an active stream. Returns true if a stream was actually cancelled,
  /// so the caller can surface a localized "stopped" toast.
  bool stopStreaming() {
    if (_streamSubscription != null) {
      _streamSubscription!.cancel();
      _streamSubscription = null;
      if (_streamCompleter != null && !_streamCompleter!.isCompleted) {
        _streamCompleter!.complete();
      }
      return true;
    }
    return false;
  }

  Future<void> _triggerAICompletion(String parentId, String? contextText,
      {BackendMode? backend}) async {
    final aiNodeId = IdGenerator.generate();
    // Resolve which engine answers this node: an explicit per-branch [backend],
    // else the current default mode (edge = local MNN, cloud = provider).
    final cfg = state.configFor(backend);

    // Append a streamable placeholder node and flip the streaming flag.
    emit(state.copyWith(
      isStreaming: true,
      currentLineage: [
        ...state.currentLineage,
        Message(
          id: aiNodeId,
          parentId: parentId,
          chatId: state.currentChatId,
          role: 'assistant',
          content: '',
          createdAt: DateTime.now(),
          isBookmarked: false,
        ),
      ],
    ));

    try {
      String aiResponse = '';

      if (cfg.apiKey.isEmpty) {
        // Offline mock when no API key is configured.
        await Future.delayed(const Duration(milliseconds: 1500));
        aiResponse = _getHighFidelityMockResponse(
          parentId: parentId,
          contextText: contextText,
        );
        await _chatRepo.insertMessage(
          id: aiNodeId,
          parentId: parentId,
          chatId: state.currentChatId,
          role: 'assistant',
          content: aiResponse,
        );
        if (isClosed) return;
        emit(state.copyWith(activeNodeId: aiNodeId, isStreaming: false));
        await loadLineage();
      } else {
        final stream = _agentEngine.submitQueryStream(
          chatId: state.currentChatId,
          userMsgId: parentId,
          provider: cfg.provider,
          providerUrl: cfg.baseUrl,
          apiKey: cfg.apiKey,
          modelName: cfg.modelName,
        );

        final completer = Completer<void>();
        _streamCompleter = completer;
        _streamSubscription = stream.listen(
          (chunk) {
            aiResponse += chunk;
            final list = [...state.currentLineage];
            final idx = list.indexWhere((m) => m.id == aiNodeId);
            if (idx != -1) {
              list[idx] = Message(
                id: aiNodeId,
                parentId: parentId,
                chatId: state.currentChatId,
                role: 'assistant',
                content: aiResponse,
                createdAt: DateTime.now(),
                isBookmarked: false,
              );
              emit(state.copyWith(currentLineage: list));
            }
          },
          onDone: () {
            _streamSubscription = null;
            if (!completer.isCompleted) completer.complete();
          },
          onError: (e) {
            _streamSubscription = null;
            if (!completer.isCompleted) completer.completeError(e);
          },
          cancelOnError: true,
        );

        // Resolves naturally (onDone), on error, or when the user taps stop.
        await completer.future;
        _streamSubscription = null;
        _streamCompleter = null;

        if (aiResponse.isNotEmpty) {
          await _chatRepo.insertMessage(
            id: aiNodeId,
            parentId: parentId,
            chatId: state.currentChatId,
            role: 'assistant',
            content: aiResponse,
          );
          if (isClosed) return;
          emit(state.copyWith(activeNodeId: aiNodeId, isStreaming: false));
        } else {
          if (isClosed) return;
          final list = [...state.currentLineage]
            ..removeWhere((m) => m.id == aiNodeId);
          emit(state.copyWith(currentLineage: list, isStreaming: false));
        }
        await loadLineage();
      }
    } catch (e) {
      _streamSubscription = null;
      _streamCompleter = null;
      if (isClosed) return;
      final list = [...state.currentLineage]
        ..removeWhere((m) => m.id == aiNodeId);
      emit(state.copyWith(isStreaming: false, currentLineage: list));
      _toastController.add('API call failed: ${_friendlyError(e)}');
      await loadLineage();
    }
  }

  String _friendlyError(Object e) {
    String errorMsg = e.toString();
    if (errorMsg.contains('HandshakeException') ||
        errorMsg.contains('CERTIFICATE') ||
        errorMsg.contains('TLS')) {
      return 'TLS handshake failed (blocked by a network security component)';
    } else if (errorMsg.contains('SocketException') ||
        errorMsg.contains('Connection refused')) {
      return 'Connection refused (check the Base URL)';
    } else if (errorMsg.contains('Connection timed out') ||
        errorMsg.contains('TimeoutException')) {
      return 'Connection timed out (unstable network or unreachable URL)';
    } else if (errorMsg.contains('API Request Failed')) {
      return errorMsg.replaceFirst('Exception: ', '');
    } else if (errorMsg.contains('401') || errorMsg.contains('Unauthorized')) {
      return 'Invalid or expired API key (401 Unauthorized)';
    } else if (errorMsg.contains('403') || errorMsg.contains('Forbidden')) {
      return 'No access to this model (403 Forbidden)';
    } else if (errorMsg.contains('404')) {
      return 'Endpoint not found (404 Not Found)';
    } else if (errorMsg.contains('429')) {
      return 'Rate limited (429 Too Many Requests)';
    }
    return errorMsg;
  }

  String _getHighFidelityMockResponse(
      {required String parentId, String? contextText}) {
    final parentMsg = state.currentLineage.firstWhere((m) => m.id == parentId);
    final text = parentMsg.content;

    final lowerText = text.toLowerCase();
    final lowerCtx = contextText?.toLowerCase() ?? '';

    if (lowerCtx.contains('event horizon')) {
      return '<think>\nAnalyzing the selected phrase "event horizon"...\nNear the singularity, spacetime curvature becomes infinite, so we need the spacetime-distortion model of general relativity.\nWe should discuss gravitational redshift under a strong gravitational field and the observer effect.\nThis positions the event horizon at the core of the scientific and cognitive knowledge tree.\n</think>\n**Branch — Event Horizon**\n\nThis impassable boundary around a black hole marks **the point where time itself appears to stop**. Because of the extreme spacetime stretching predicted by general relativity, any object seen falling toward the horizon from the outside appears to slow down without limit, redshifting away at the edge. It is relativity taken to its absolute extreme.';
    }

    if (lowerText.contains('table') || lowerText.contains('test')) {
      return '<think>\nThinking about the ideal aesthetics of tables and rich-text layout...\nProvide a high-contrast multi-column Markdown table plus a code block so the user can verify rendering end to end.\nMake sure there are no hard-coded scrollbars or awkward line breaks.\n</think>\nHere is a multi-dimensional comparison table:\n\n| Dimension | Classical chat | Dendrite (tree) |\n| :--- | :--- | :--- |\n| **Data flow** | Linear chain | Recursively branching tree |\n| **Context inheritance** | Whole-history overlap | Precise ancestral lineage |\n| **Emphasis** | No inline accents | Inline capsule badges |\n\nYou can scroll the table horizontally — and notice there is no stuck progress bar at the bottom.';
    }

    if (lowerText.contains('black hole') || lowerText.contains('event horizon')) {
      return '<think>\nThe user is asking about black holes or their properties.\nBasic structure: singularity, event horizon, accretion disk, jets.\nFocus on the boundary effect, and gently point out Dendrite\'s branch-brainstorming feature.\n</think>\nA black hole is the most extreme object in the universe. Around it lies a final boundary called the "**event horizon**". Once you cross it, the escape velocity exceeds the speed of light and all causal connection to the outside is severed.\n\n💡 Tip: select any text above to bring up the context menu and start a new branch (Branch Ask) to dig deeper!';
    }

    if (lowerText.contains('sqlite') || lowerText.contains('recursive')) {
      return '<think>\nThinking about the database and the recursive mechanism that tracks the conversation tree.\nDrift is built on SQLite.\nShow a WITH RECURSIVE SQL expression to demonstrate millisecond-level ancestor lineage loading.\n</think>\nWith local SQLite (Drift), a `WITH RECURSIVE` common table expression lets us walk every ancestor node upward:\n\n```sql\nWITH RECURSIVE lineage(id, parent) AS (\n  SELECT id, parent FROM messages WHERE id = ?\n  UNION ALL\n  SELECT m.id, m.parent FROM messages m, lineage l WHERE m.id = l.parent\n)\nSELECT * FROM lineage;\n```\nThis lets Dendrite rebuild any complex conversation tree locally in milliseconds — lightweight and reliable.';
    }

    return '<think>\nBuilding a generic branch node...\nCurrent parent node: "$parentId", selected text: "${contextText ?? "none"}".\nWorking out how to create an independent parallel sub-space for the user...\n</think>\nThis is a brand-new branch of inquiry. Dendrite has merged the parent node, your selected text "${contextText ?? "none"}", and this question into one complete ancestral context, ready for this independent branch to evolve.';
  }

  // --- Search & bookmarks ---

  Future<void> performSearch(String query) async {
    if (query.trim().isEmpty) {
      emit(state.copyWith(searchResults: [], isSearching: false));
      return;
    }
    final results = await _chatRepo.search(query);
    if (isClosed) return;
    emit(state.copyWith(searchResults: results, isSearching: true));
  }

  Future<void> toggleBookmark(Message node) async {
    await _chatRepo.setBookmark(node, !node.isBookmarked);
    await loadLineage();
  }

  // --- Import / export (data only; the UI shows the localized toast) ---

  /// Exports the current chat to JSON. Returns the file path on success.
  Future<String?> exportConversation() async {
    try {
      final data = state.allNodesInChat
          .map((n) => {
                'id': n.id,
                'parentId': n.parentId,
                'chatId': n.chatId,
                'role': n.role,
                'content': n.content,
                'associatedSelection': n.associatedSelection,
                'isBookmarked': n.isBookmarked,
              })
          .toList();

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getApplicationDocumentsDirectory();
      final file =
          File(p.join(dir.path, 'dendrite_export_${state.currentChatId}.json'));
      await file.writeAsString(jsonString);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Serializes the ENTIRE conversation tree (every branch, not just the active
  /// lineage) into structured Markdown. Branch questions become nested headings
  /// so a downstream tool (e.g. a slide generator) can turn the knowledge tree
  /// into an outline. Internal `<think>…</think>` reasoning is stripped.
  String buildTreeMarkdown() {
    final nodes = state.allNodesInChat;
    if (nodes.isEmpty) return '# Dendrite\n\n_(empty conversation)_\n';

    final childrenMap = <String, List<Message>>{};
    Message? root;
    for (final n in nodes) {
      if (n.parentId == null) {
        root ??= n;
      } else {
        childrenMap.putIfAbsent(n.parentId!, () => []).add(n);
      }
    }
    root ??= nodes.first;

    String clean(String s) => s
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>', multiLine: true), '')
        .trim();
    String oneLine(String s) =>
        s.replaceAll(RegExp(r'\s+'), ' ').trim();

    final firstUser =
        nodes.firstWhere((n) => n.role == 'user', orElse: () => root!);
    final branchCount =
        nodes.where((n) => n.associatedSelection != null).length;

    final sb = StringBuffer()
      ..writeln('# Dendrite — 知识树导出')
      ..writeln()
      ..writeln('> **主题：** ${oneLine(firstUser.content)}')
      ..writeln('>')
      ..writeln('> **节点数：** ${nodes.length} · **分支数：** $branchCount · '
          '导出时间：${DateTime.now().toIso8601String().substring(0, 19)}')
      ..writeln();

    void walk(Message node, int branchDepth) {
      if (node.role == 'user') {
        final isBranch = node.associatedSelection != null;
        final hashes = '#' * ((branchDepth + 2).clamp(2, 6));
        if (isBranch) {
          sb
            ..writeln('$hashes 🌿 分支：「${oneLine(node.associatedSelection!)}」')
            ..writeln()
            ..writeln('> 选中上下文：${oneLine(node.associatedSelection!)}')
            ..writeln();
        } else {
          sb..writeln('$hashes 提问')..writeln();
        }
        sb..writeln('**Q：** ${clean(node.content)}')..writeln();
      } else {
        sb..writeln('**A：** ${clean(node.content)}')..writeln();
        if (node.isBookmarked) {
          sb..writeln('> ⭐ 已收藏的关键结论')..writeln();
        }
      }
      for (final child in childrenMap[node.id] ?? const <Message>[]) {
        final deeper = child.role == 'user' && child.associatedSelection != null;
        walk(child, deeper ? branchDepth + 1 : branchDepth);
      }
    }

    walk(root, 0);
    return sb.toString();
  }

  /// Builds the tree Markdown and saves it (browser download on web, documents
  /// directory on mobile/desktop). Returns the path/filename, or null on error.
  Future<String?> exportTreeMarkdown() async {
    try {
      final markdown = buildTreeMarkdown();
      final filename = 'dendrite_tree_${state.currentChatId}.md';
      return await saveTreeMarkdown(filename, markdown);
    } catch (_) {
      return null;
    }
  }

  Future<ImportResult> importConversation() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file =
          File(p.join(dir.path, 'dendrite_export_${state.currentChatId}.json'));
      if (!await file.exists()) {
        return ImportResult.notFound;
      }

      final List<dynamic> data = jsonDecode(await file.readAsString());
      for (final item in data) {
        await _chatRepo.insertMessage(
          id: item['id'],
          parentId: item['parentId'],
          chatId: item['chatId'],
          role: item['role'],
          content: item['content'],
          associatedSelection: item['associatedSelection'],
          isBookmarked: item['isBookmarked'] ?? false,
          upsert: true,
        );
      }
      await loadLineage();
      return ImportResult.success;
    } catch (_) {
      return ImportResult.error;
    }
  }

  @override
  Future<void> close() async {
    await _streamSubscription?.cancel();
    await _toastController.close();
    _ingestService.dispose();
    await _db.close();
    return super.close();
  }
}
