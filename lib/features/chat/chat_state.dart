import 'package:dendrite/core/db/database.dart';
import 'package:dendrite/core/models/api_config.dart';

/// Immutable state for the chat feature, owned by [ChatCubit].
class ChatState {
  final bool initialized;
  final String currentChatId;
  final String? activeNodeId;
  final List<Message> currentLineage;
  final List<Message> allNodesInChat;
  final List<String> branchHistory;
  final bool isStreaming;
  final ApiConfig apiConfig;
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
    this.apiConfig = const ApiConfig(
      provider: 'nvidia',
      baseUrl: 'https://integrate.api.nvidia.com/v1',
      apiKey: '',
      modelName: 'meta/llama-3.1-70b-instruct',
    ),
    this.searchResults = const [],
    this.isSearching = false,
  });

  static const Object _unset = Object();

  ChatState copyWith({
    bool? initialized,
    String? currentChatId,
    Object? activeNodeId = _unset,
    List<Message>? currentLineage,
    List<Message>? allNodesInChat,
    List<String>? branchHistory,
    bool? isStreaming,
    ApiConfig? apiConfig,
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
      apiConfig: apiConfig ?? this.apiConfig,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

/// Outcome of an import attempt, so the UI can show the right localized toast.
enum ImportResult { success, notFound, error }
