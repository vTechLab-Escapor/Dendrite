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
import 'package:dendrite/features/chat/chat_state.dart';
import 'package:dendrite/features/settings/settings_repository.dart';

/// Owns all chat data state, persistence and the AI streaming lifecycle.
class ChatCubit extends Cubit<ChatState> {
  late final AppDatabase _db;
  late final ChatRepository _chatRepo;
  late final AgentEngine _agentEngine;
  final SettingsRepository _settingsRepo;

  StreamSubscription<String>? _streamSubscription;
  Completer<void>? _streamCompleter;

  // One-off, already-composed messages for the UI to surface as toasts.
  final StreamController<String> _toastController =
      StreamController<String>.broadcast();
  Stream<String> get toasts => _toastController.stream;

  ChatCubit({AppDatabase? db, SettingsRepository? settingsRepo})
      : _settingsRepo = settingsRepo ?? SettingsRepository(),
        super(const ChatState()) {
    _db = db ?? AppDatabase();
    _chatRepo = ChatRepository(_db);
    _agentEngine = AgentEngine(db: _db);
  }

  Future<void> init() async {
    final config = await _settingsRepo.load();
    if (isClosed) return;
    emit(state.copyWith(apiConfig: config));
    await loadLineage();
    if (isClosed) return;
    emit(state.copyWith(initialized: true));
  }

  Future<void> updateConfig(ApiConfig config) async {
    emit(state.copyWith(apiConfig: config));
    await _settingsRepo.save(config);
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

  Future<void> sendMessage(String finalContent) async {
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
    await _triggerAICompletion(userMsgId, null);
  }

  Future<void> createBranchQuestion(
      String sourceNodeId, String contextText, String question) async {
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
    await _triggerAICompletion(userMsgId, contextText);
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

  Future<void> _triggerAICompletion(String parentId, String? contextText) async {
    final aiNodeId = IdGenerator.generate();

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

      if (state.apiConfig.apiKey.isEmpty) {
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
          provider: state.apiConfig.provider,
          providerUrl: state.apiConfig.baseUrl,
          apiKey: state.apiConfig.apiKey,
          modelName: state.apiConfig.modelName,
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
      _toastController.add('API调用失败: ${_friendlyError(e)}');
      await loadLineage();
    }
  }

  String _friendlyError(Object e) {
    String errorMsg = e.toString();
    if (errorMsg.contains('HandshakeException') ||
        errorMsg.contains('CERTIFICATE') ||
        errorMsg.contains('TLS')) {
      return 'TLS证书握手失败 (华为网络安全组件拦截)';
    } else if (errorMsg.contains('SocketException') ||
        errorMsg.contains('Connection refused')) {
      return '网络连接被拒绝 (请检查Base URL)';
    } else if (errorMsg.contains('Connection timed out') ||
        errorMsg.contains('TimeoutException')) {
      return '连接超时 (网络不稳定或URL不可达)';
    } else if (errorMsg.contains('API Request Failed')) {
      return errorMsg.replaceFirst('Exception: ', '');
    } else if (errorMsg.contains('401') || errorMsg.contains('Unauthorized')) {
      return 'API密钥无效或已过期 (401 Unauthorized)';
    } else if (errorMsg.contains('403') || errorMsg.contains('Forbidden')) {
      return '无权限访问此模型 (403 Forbidden)';
    } else if (errorMsg.contains('404')) {
      return '接口地址不存在 (404 Not Found)';
    } else if (errorMsg.contains('429')) {
      return '请求频率过高 (429 Rate Limited)';
    }
    return errorMsg;
  }

  String _getHighFidelityMockResponse(
      {required String parentId, String? contextText}) {
    final parentMsg = state.currentLineage.firstWhere((m) => m.id == parentId);
    final text = parentMsg.content;

    if (contextText != null && contextText.contains('事件视界')) {
      return '<think>\n正在分析用户选中的词组「事件视界」...\n在奇点周围，时空的曲率无穷大，我们需要引入广义相对论的时空扭曲模型。\n需要探讨强引力场下的引力红移以及观察者效应（Event Horizon Observable Effect）。\n由此引出事件视界在科学及认知树状图谱中的核心定位。\n</think>\n【分叉探究：事件视界】\n\n黑洞周围的这道不可逾越的边界，代表着**引力奇点的时间停止点**。由于强烈的广义相对论时空拉伸效应，任何从外部观察落向事件视界的物体，其时间流速似乎会无限减慢，最终在视界边缘红移消失。这证明了时空的相对性在这里达到了极致！';
    }

    if (text.contains('表格') || text.contains('测试') || text.contains('table')) {
      return '<think>\n分析关于表格和富文本排版的终极美学...\n需要提供一个包含真实多列对比的高对比度 Markdown 表格，并搭配一段代码块以便用户全方位核验。\n确保没有任何硬编码滚动条或视觉突兀的换行。\n</think>\n这里是为你生成的学术多维特征对比表：\n\n| 特征维度 | 经典模型 (Classical) | 树状多分叉 (Dendrite) |\n| :--- | :--- | :--- |\n| **数据流向** | 线性链式 (Linear) | 多叉树无限分裂 (Recursive) |\n| **上下文继承** | 全量重叠 (Overlapped) | 精准 ancestral 谱系溯源 |\n| **高光状态** | 无 inline 强调 | 基线内嵌微缩胶囊徽章 |\n\n你可以自由横向滑动此表格进行查阅。同时，底部已彻底抹去了死锁进度条！';
    }

    if (text.contains('事件视界') || text.contains('黑洞')) {
      return '<think>\n用户询问关于黑洞或其特征。\n黑洞的基本构造：奇点、事件视界、吸积盘、喷流。\n应该重点阐述其边界效应，并温馨提示 Dendrite 的分支脑暴特性。\n</think>\n黑洞是宇宙中最极端的天体。在其外部存在着被称为“**事件视界**”的最终分界线。一旦穿过该边界，逃逸速度将超越光速，导致任何因果关联彻底切断。\n\n💡 提示：在上方选词即可拉起 context menu 创立新支流（Branch Ask）进行深度脑暴！';
    }

    if (text.contains('SQLite') || text.contains('递归')) {
      return '<think>\n分析关于数据库和树状多支流追踪的递归机制。\nDrift ORM 底层是 SQLite。\n需要展示 WITH RECURSIVE SQL 表达式以便直观证明其毫秒级多代祖先溯源（lineage loading）实力。\n</think>\n在本地 SQLite(Drift) 开发中，利用 `WITH RECURSIVE` 公用表表达式，我们可以向上无限追踪所有的 ancestor 节点：\n\n```sql\nWITH RECURSIVE lineage(id, parent) AS (\n  SELECT id, parent FROM messages WHERE id = ?\n  UNION ALL\n  SELECT m.id, m.parent FROM messages m, lineage l WHERE m.id = l.parent\n)\nSELECT * FROM lineage;\n```\n这让 Dendrite 可以在毫秒内完美、轻量、稳定地在本地复原任意复杂的树状上下文！';
    }

    return '<think>\n建立通用分支衍生节点...\n当前上下文父节点：「$parentId」，选中词汇：「${contextText ?? "无"}」。\n分析如何为用户建立独立的多代并行子空间...\n</think>\n这是一个全新的分叉研究方向。Dendrite 已为你将父级节点、选中文字「${contextText ?? "无"}」与本提问融合作为完整的 ancestral context，供该独立分支继续演化。';
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
    await _db.close();
    return super.close();
  }
}
