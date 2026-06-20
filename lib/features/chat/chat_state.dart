import 'package:dendrite/core/db/database.dart';
import 'package:dendrite/core/models/api_config.dart';

/// Which inference backend answers a question:
/// - [edge]  = on-device / local MNN server (privacy, offline, zero cost)
/// - [cloud] = a hosted OpenAI-compatible provider (max capability)
enum BackendMode { edge, cloud }

/// Immutable state for the chat feature, owned by [ChatCubit].
class ChatState {
  final bool initialized;
  final String currentChatId;
  final String? activeNodeId;
  final List<Message> currentLineage;
  final List<Message> allNodesInChat;
  final List<String> branchHistory;
  final bool isStreaming;
  final bool isIngesting;
  final ApiConfig apiConfig; // cloud provider config
  final ApiConfig localConfig; // edge / local MNN config
  final BackendMode backendMode; // default backend for new questions
  final List<Message> searchResults;
  final bool isSearching;

  const ChatState({
    this.initialized = false,
    this.currentChatId = 'default_chat',
    this.activeNodeId,
    this.currentLineage = const [],
    this.allNodesInChat = const [],
    this.branchHistory = const [],
    this.isStreaming = false,
    this.isIngesting = false,
    this.apiConfig = const ApiConfig(
      provider: 'nvidia',
      baseUrl: 'https://integrate.api.nvidia.com/v1',
      apiKey: '',
      modelName: 'meta/llama-3.1-70b-instruct',
    ),
    this.localConfig = const ApiConfig(
      provider: 'mnn',
      baseUrl: 'http://localhost:8080/v1',
      apiKey: 'sk-local',
      modelName: 'Qwen3-1.7B-MNN',
    ),
    this.backendMode = BackendMode.cloud,
    this.searchResults = const [],
    this.isSearching = false,
  });

  /// The config for the current default backend.
  ApiConfig get activeConfig =>
      backendMode == BackendMode.edge ? localConfig : apiConfig;

  /// The config for an explicit backend, falling back to the default mode.
  ApiConfig configFor(BackendMode? mode) =>
      (mode ?? backendMode) == BackendMode.edge ? localConfig : apiConfig;

  static const Object _unset = Object();

  ChatState copyWith({
    bool? initialized,
    String? currentChatId,
    Object? activeNodeId = _unset,
    List<Message>? currentLineage,
    List<Message>? allNodesInChat,
    List<String>? branchHistory,
    bool? isStreaming,
    bool? isIngesting,
    ApiConfig? apiConfig,
    ApiConfig? localConfig,
    BackendMode? backendMode,
    List<Message>? searchResults,
    bool? isSearching,
  }) {
    return ChatState(
      initialized: initialized ?? this.initialized,
      currentChatId: currentChatId ?? this.currentChatId,
      activeNodeId: identical(activeNodeId, _unset)
          ? this.activeNodeId
          : activeNodeId as String?,
      currentLineage: currentLineage ?? this.currentLineage,
      allNodesInChat: allNodesInChat ?? this.allNodesInChat,
      branchHistory: branchHistory ?? this.branchHistory,
      isStreaming: isStreaming ?? this.isStreaming,
      isIngesting: isIngesting ?? this.isIngesting,
      apiConfig: apiConfig ?? this.apiConfig,
      localConfig: localConfig ?? this.localConfig,
      backendMode: backendMode ?? this.backendMode,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

/// Outcome of an import attempt, so the UI can show the right localized toast.
enum ImportResult { success, notFound, error }
