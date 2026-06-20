import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:file_picker/file_picker.dart';
import 'package:dendrite/core/db/database.dart';
import 'package:dendrite/core/models/api_config.dart';
import 'package:dendrite/features/chat/chat_cubit.dart';
import 'package:dendrite/features/chat/chat_state.dart';
import 'package:dendrite/features/chat/chat_tree.dart';
import 'package:dendrite/features/ingest/ingest_models.dart';
import 'package:dendrite/features/ingest/url_detector.dart';
import 'package:dendrite/features/chat/widgets/selection_menu.dart';
import 'package:dendrite/features/map/widgets/mind_map_canvas.dart';
import 'package:dendrite/features/chat/demo_hook_stub.dart'
    if (dart.library.js_interop) 'package:dendrite/features/chat/demo_hook_web.dart';

/// Built with --dart-define=DENDRITE_E2E=true: exposes an offstage mirror of the
/// latest assistant reply so integration_test can assert the round-trip.
const bool kE2E = bool.fromEnvironment('DENDRITE_E2E');

/// Built with --dart-define=DENDRITE_DEMO=true: holds toasts on screen longer so
/// they are legible when capturing the demo video. No effect on normal builds.
const bool kDemo = bool.fromEnvironment('DENDRITE_DEMO');

/// Brand palette — single, locked accent across the whole app.
///
/// Dendrite's identity is the *branch*: the teal below is the one accent the UI
/// is allowed to reach for, and it is reserved for branch-related affordances
/// (inline branch chips, the branched-route banner, active tree nodes, the
/// reasoning/thinking state). Everything else stays neutral monochrome.
/// Gold is a separate, conventional semantic used ONLY for bookmarks.
const Color kBrandAccent = Color(0xFF10A37F);
const Color kBrandAccentBright = Color(0xFF19C37D);
const Color kBookmarkGold = Color(0xFFFFB800);

/// One corner-radius scale for the page (taste: SHAPE CONSISTENCY LOCK).
/// pill = fully rounded interactive, lg = cards/surfaces, md = inputs/chips.
class R {
  static const double pill = 26;
  static const double lg = 16;
  static const double md = 12;
  static const double sm = 8;
}

/// Centered reading column. Without this the chat sprawls edge-to-edge on
/// desktop/web; a fixed measure keeps line length comfortable (taste: contain
/// page layouts) and matches the mental model of every modern chat UI.
const double kMaxContentWidth = 760;

/// Wraps [child] in a centred, width-capped column.
Widget _centered(Widget child) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: child,
      ),
    );

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // All chat data state + persistence + AI streaming lives in the cubit.
  late final ChatCubit _cubit;
  StreamSubscription<String>? _toastSub;

  // Chat data state is read from the cubit; these getters keep the (read-only)
  // call sites throughout the widget unchanged.
  ChatState get _cs => _cubit.state;
  bool get _isDbInitialized => _cs.initialized;
  String get _currentChatId => _cs.currentChatId;
  String? get _activeNodeId => _cs.activeNodeId;
  List<Message> get _currentLineage => _cs.currentLineage;
  List<Message> get _allNodesInChat => _cs.allNodesInChat;
  bool get _isStreaming => _cs.isStreaming;
  bool get _isIngesting => _cs.isIngesting;
  List<Message> get _searchResults => _cs.searchResults;
  bool get _isSearching => _cs.isSearching;
  String get _apiProvider => _cs.apiConfig.provider;
  String get _apiBaseUrl => _cs.apiConfig.baseUrl;
  String get _apiKey => _cs.apiConfig.apiKey;
  String get _apiModelName => _cs.apiConfig.modelName;

  // UI-only state (not shared with the cubit).
  final List<File> _selectedFiles = [];
  final List<String> _selectedFileNames = [];
  bool _isMindMapMode = false;
  bool _isDarkMode = false;
  bool _obscureApiKey = true;
  final Set<String> _expandedThinkingNodeIds = {};
  String _currentLanguage = 'zh'; // Default to Chinese (demo recording build; was 'en')

  static const Map<String, Map<String, String>> _translations = {
    'zh': {
      'app_title': 'Dendrite 1.0',
      'welcome_title': '我可以帮您什么？',
      'welcome_subtitle': '树状双向多支流 AI 聊天助理',
      'input_hint': '给 Dendrite 发送消息...',
      'search_hint': '全文检索历史聊天...',
      'bookmark_header': '⭐ 收藏消息 (Bookmarks)',
      'history_header': '💬 最近聊天记录 (History)',
      'backup_import': '导入备份',
      'backup_export': '导出历史',
      'developer_mode': 'API & 开发者管理',
      'settings_title': 'API 引擎配置中心',
      'settings_provider': '服务商 (Provider)',
      'settings_url': '接口基地址 (Base URL)',
      'settings_key': '接口密钥 (API Key)',
      'settings_model': '目标模型名称 (Model Name)',
      'settings_cancel': '取消',
      'settings_save': '保存配置',
      'branch_ask_title': '🌿 创建分叉对话',
      'branch_context': '上下文 (Context Selection)',
      'branch_question': '分支新问题 (Branch Ask)',
      'branch_input_hint': '就此上下文发起新问题...',
      'branch_route_banner': '已切换至分叉支流路线',
      'branch_return_main': '返回主干',
      'branch_return_parent': '返回上级',
      'toast_new_chat': '已开启全新极简对话线程',
      'toast_branch_saved': '⭐ 分叉消息收藏成功！',
      'toast_bookmark_removed': '已取消消息收藏',
      'toast_settings_saved': 'API 引擎配置保存成功！',
      'mode_edge': '本地',
      'mode_cloud': '云端',
      'mode_edge_full': '本地推理 (Edge · MNN)',
      'mode_cloud_full': '云端推理 (Cloud)',
      'settings_mode': '默认推理后端 (Default Backend)',
      'settings_local_title': '本地推理 · MNN (Edge)',
      'settings_local_url': '本地服务地址 (MNN Base URL)',
      'settings_local_model': '本地模型 (Local Model)',
      'toast_mode_edge': '已切换至「本地」推理 — 离线 · 隐私 · 零成本',
      'toast_mode_cloud': '已切换至「云端」推理 — 最强能力',
      'branch_engine': '本分支引擎 (Branch Engine)',
      'branch_engine_default': '跟随默认',
      'toast_returned_parent': '已返回上级消息对话流',
      'toast_import_success': '数据导入并合并成功！',
      'toast_export_success': '数据导出成功',
      'toast_stopped': '已停止生成',
      'toast_copied': '已复制到剪贴板',
      'toast_jump_bookmark': '跳转至收藏节点分支',
      'thinking_active': '思考中...',
    },
    'en': {
      'app_title': 'Dendrite 1.0',
      'welcome_title': 'How can I help you?',
      'welcome_subtitle': 'Tree-structured Multi-branch AI Assistant',
      'input_hint': 'Message Dendrite...',
      'search_hint': 'Search chat history...',
      'bookmark_header': '⭐ Bookmarked Messages',
      'history_header': '💬 Recent History',
      'backup_import': 'Import Backup',
      'backup_export': 'Export History',
      'developer_mode': 'API & Developer Management',
      'settings_title': 'API Configuration Center',
      'settings_provider': 'Provider',
      'settings_url': 'Base URL',
      'settings_key': 'API Key',
      'settings_model': 'Model Name',
      'settings_cancel': 'Cancel',
      'settings_save': 'Save Settings',
      'branch_ask_title': '🌿 Create Branched Chat',
      'branch_context': 'Context Selection',
      'branch_question': 'Branch Ask',
      'branch_input_hint': 'Ask a question based on this context...',
      'branch_route_banner': 'Switched to branched context line',
      'branch_return_main': 'Back to Main',
      'branch_return_parent': 'Back to Parent',
      'toast_new_chat': 'New chat thread started',
      'toast_branch_saved': '⭐ Message bookmarked successfully!',
      'toast_bookmark_removed': 'Message removed from bookmarks',
      'toast_settings_saved': 'API configuration saved successfully!',
      'mode_edge': 'Edge',
      'mode_cloud': 'Cloud',
      'mode_edge_full': 'Edge · On-device (MNN)',
      'mode_cloud_full': 'Cloud',
      'settings_mode': 'Default Backend',
      'settings_local_title': 'Edge · On-device (MNN)',
      'settings_local_url': 'MNN Base URL',
      'settings_local_model': 'Local Model',
      'toast_mode_edge': 'Switched to Edge — offline · private · zero-cost',
      'toast_mode_cloud': 'Switched to Cloud — maximum capability',
      'branch_engine': 'Branch Engine',
      'branch_engine_default': 'Default',
      'toast_returned_parent': 'Returned to the parent conversation',
      'toast_import_success': 'Data imported and merged successfully!',
      'toast_export_success': 'Data exported successfully',
      'toast_stopped': 'Generation stopped',
      'toast_copied': 'Copied to clipboard',
      'toast_jump_bookmark': 'Jumped to bookmarked branch',
      'thinking_active': 'Thinking...',
    },
    'fr': {
      'app_title': 'Dendrite 1.0',
      'welcome_title': 'Comment puis-je vous aider?',
      'welcome_subtitle': 'Assistant IA arborescent multi-branches',
      'input_hint': 'Envoyer un message...',
      'search_hint': 'Rechercher dans l\'historique...',
      'bookmark_header': '⭐ Messages Favoris',
      'history_header': '💬 Historique Récent',
      'backup_import': 'Importer la sauvegarde',
      'backup_export': 'Exporter l\'historique',
      'developer_mode': 'Gestion des API',
      'settings_title': 'Configuration de l\'API',
      'settings_provider': 'Fournisseur',
      'settings_url': 'URL de Base',
      'settings_key': 'Clé API',
      'settings_model': 'Nom du Modèle',
      'settings_cancel': 'Annuler',
      'settings_save': 'Sauvegarder',
      'branch_ask_title': '🌿 Créer une branche',
      'branch_context': 'Sélection de contexte',
      'branch_question': 'Question de branche',
      'branch_input_hint': 'Poser une question sur ce contexte...',
      'branch_route_banner': 'Passé à la ligne de contexte branchée',
      'branch_return_main': 'Retour au principal',
      'toast_new_chat': 'Nouveau fil de discussion lancé',
      'toast_branch_saved': '⭐ Message favori enregistré !',
      'toast_bookmark_removed': 'Message retiré des favoris',
      'toast_settings_saved': 'Configuration API enregistrée !',
      'toast_import_success': 'Sauvegarde importée avec succès !',
      'toast_export_success': 'Historique exporté avec succès',
    },
    'de': {
      'app_title': 'Dendrite 1.0',
      'welcome_title': 'Wie kann ich helfen?',
      'welcome_subtitle': 'Baumstrukturierter KI-Assistent',
      'input_hint': 'Nachricht an Dendrite...',
      'search_hint': 'Chatverlauf durchsuchen...',
      'bookmark_header': '⭐ Lesezeichen',
      'history_header': '💬 Verlauf',
      'backup_import': 'Backup importieren',
      'backup_export': 'Verlauf exportieren',
      'developer_mode': 'API-Verwaltung',
      'settings_title': 'API-Einstellungen',
      'settings_provider': 'Anbieter',
      'settings_url': 'Basis-URL',
      'settings_key': 'API-Schlüssel',
      'settings_model': 'Modellname',
      'settings_cancel': 'Abbrechen',
      'settings_save': 'Speichern',
      'branch_ask_title': '🌿 Branch erstellen',
      'branch_context': 'Kontext-Auswahl',
      'branch_question': 'Frage an Branch',
      'branch_input_hint': 'Stelle eine Frage zu diesem Kontext...',
      'branch_route_banner': 'Zum verzweigten Kontext gewechselt',
      'branch_return_main': 'Zurück zum Hauptpfad',
      'branch_return_parent': 'Zurück zur Ebene',
      'toast_new_chat': 'Neuer Chat gestartet',
      'toast_branch_saved': '⭐ Nachricht gespeichert!',
      'toast_bookmark_removed': 'Nachricht aus Lesezeichen entfernt',
      'toast_settings_saved': 'API-Einstellungen gespeichert!',
      'toast_returned_parent': 'Zur übergeordneten Ebene zurückgekehrt',
      'toast_import_success': 'Daten erfolgreich importiert!',
      'toast_export_success': 'Erfolgreich exportiert',
    },
    'es': {
      'app_title': 'Dendrite 1.0',
      'welcome_title': '¿Cómo puedo ayudarte?',
      'welcome_subtitle': 'Asistente de IA arborescente de múltiples ramas',
      'input_hint': 'Escribe a Dendrite...',
      'search_hint': 'Buscar en el historial...',
      'bookmark_header': '⭐ Mensajes Guardados',
      'history_header': '💬 Historial Reciente',
      'backup_import': 'Importar copia',
      'backup_export': 'Exportar historial',
      'developer_mode': 'Gestión de API',
      'settings_title': 'Configuración de API',
      'settings_provider': 'Proveedor',
      'settings_url': 'URL Base',
      'settings_key': 'Clave API',
      'settings_model': 'Nombre del Modelo',
      'settings_cancel': 'Cancelar',
      'settings_save': 'Guardar',
      'branch_ask_title': '🌿 Crear ramificación',
      'branch_context': 'Selección de contexto',
      'branch_question': 'Pregunta de rama',
      'branch_input_hint': 'Haz una pregunta sobre este contexto...',
      'branch_route_banner': 'Cambiado a la línea de contexto ramificada',
      'branch_return_main': 'Volver al principal',
      'toast_new_chat': 'Nueva conversación iniciada',
      'toast_branch_saved': '⭐ ¡Mensaje guardado con éxito!',
      'toast_bookmark_removed': 'Mensaje eliminado de favoritos',
      'toast_settings_saved': 'Configuración guardada correctamente',
      'toast_import_success': 'Datos importados con éxito',
      'toast_export_success': 'Datos exportados correctamente',
    },
    'ja': {
      'app_title': 'Dendrite 1.0',
      'welcome_title': 'どのようなお手伝いが必要ですか？',
      'welcome_subtitle': 'ツリー構造双方向多分岐AIアシスタント',
      'input_hint': 'メッセージを入力...',
      'search_hint': '履歴を全文検索...',
      'bookmark_header': '⭐ お気に入りメッセージ',
      'history_header': '💬 最近の履歴',
      'backup_import': 'バックアップを読み込む',
      'backup_export': '履歴を書き出す',
      'developer_mode': 'API・開発者管理',
      'settings_title': 'API エンジン設定',
      'settings_provider': 'プロバイダー',
      'settings_url': 'ベースURL',
      'settings_key': 'APIキー',
      'settings_model': '対象モデル名',
      'settings_cancel': 'キャンセル',
      'settings_save': '設定を保存',
      'branch_ask_title': '🌿 分岐会話を作成',
      'branch_context': '選択された文脈',
      'branch_question': '分岐質問',
      'branch_input_hint': 'この文脈について質問する...',
      'branch_route_banner': '分岐コンテキストラインに切り替わりました',
      'branch_return_main': 'メインに戻る',
      'branch_return_parent': '上に戻る',
      'toast_new_chat': '新しいチャットスレッドを開始しました',
      'toast_branch_saved': '⭐ メッセージをお気に入りに保存しました！',
      'toast_bookmark_removed': 'お気に入りから削除しました',
      'toast_settings_saved': 'API設定を保存しました！',
      'toast_returned_parent': '親会話に戻りました',
      'toast_import_success': 'データを正常にインポートしました！',
      'toast_export_success': 'データを正常にエクスポートしました',
    },
    'ko': {
      'app_title': 'Dendrite 1.0',
      'welcome_title': '무엇을 도와드릴까요?',
      'welcome_subtitle': '트리 구조 쌍방향 다중 분기 AI 어시스턴트',
      'input_hint': '메시지 입력...',
      'search_hint': '대화 기록 검색...',
      'bookmark_header': '⭐ 즐겨찾는 메시지',
      'history_header': '💬 최근 기록',
      'backup_import': '백업 가져오기',
      'backup_export': '기록 내보내기',
      'developer_mode': 'API 및 개발자 관리',
      'settings_title': 'API 설정 센터',
      'settings_provider': '제공업체',
      'settings_url': '기본 URL',
      'settings_key': 'API 키',
      'settings_model': '모델 이름',
      'settings_cancel': '취소',
      'settings_save': '설정 저장',
      'branch_ask_title': '🌿 분기 대화 만들기',
      'branch_context': '선택된 콘텍스트',
      'branch_question': '분기 질문',
      'branch_input_hint': '이 문맥을 기반으로 질문하기...',
      'branch_route_banner': '분기된 컨텍스트 라인으로 전환됨',
      'branch_return_main': '메인으로 돌아가기',
      'branch_return_parent': '이전 분기로',
      'toast_new_chat': '새 대화가 시작되었습니다',
      'toast_branch_saved': '⭐ 메시지가 즐겨찾기에 저장되었습니다!',
      'toast_bookmark_removed': '즐겨찾기에서 제거되었습니다',
      'toast_settings_saved': 'API 설정이 저장되었습니다!',
      'toast_returned_parent': '상위 대화로 돌아갔습니다',
      'toast_import_success': '성공적으로 백업을 가져왔습니다!',
      'toast_export_success': '성공적으로 기록을 내보냈습니다',
    },
    'ru': {
      'app_title': 'Dendrite 1.0',
      'welcome_title': 'Чем я могу помочь?',
      'welcome_subtitle': 'Древовидный многоветвистый ИИ-ассистент',
      'input_hint': 'Напишите Dendrite...',
      'search_hint': 'Поиск по истории...',
      'bookmark_header': '⭐ Избранные сообщения',
      'history_header': '💬 Последние чаты',
      'backup_import': 'Импорт бэкапа',
      'backup_export': 'Экспорт истории',
      'developer_mode': 'Управление API',
      'settings_title': 'Настройки движка API',
      'settings_provider': 'Провайдер',
      'settings_url': 'Базовый URL',
      'settings_key': 'API Ключ',
      'settings_model': 'Имя модели',
      'settings_cancel': 'Отмена',
      'settings_save': 'Сохранить',
      'branch_ask_title': '🌿 Создать ветку беседы',
      'branch_context': 'Выбранный контекст',
      'branch_question': 'Вопрос в ветку',
      'branch_input_hint': 'Задать вопрос по этому контексту...',
      'branch_route_banner': 'Переключено на ветку контекста',
      'branch_return_main': 'Назад к основе',
      'toast_new_chat': 'Начата новая ветка чата',
      'toast_branch_saved': '⭐ Сообщение добавлено в избранное!',
      'toast_bookmark_removed': 'Сообщение удалено из избранного',
      'toast_settings_saved': 'Конфигурация API успешно сохранена!',
      'toast_import_success': 'Данные успешно импортированы!',
      'toast_export_success': 'История успешно экспортирована',
    },
    'ar': {
      'app_title': 'Dendrite 1.0',
      'welcome_title': 'كيف يمكنني مساعدتك؟',
      'welcome_subtitle': 'مساعد ذكاء اصطناعي شجري متعدد الفروع',
      'input_hint': 'أرسل رسالة إلى Dendrite...',
      'search_hint': 'البحث في سجل المحادثات...',
      'bookmark_header': '⭐ الرسائل المفضلة',
      'history_header': '💬 المحادثات الأخيرة',
      'backup_import': 'استيراد النسخة الاحتياطية',
      'backup_export': 'تصدير السجل',
      'developer_mode': 'إدارة واجهة برمجة التطبيقات API',
      'settings_title': 'مركز تهيئة واجهة API',
      'settings_provider': 'المزود',
      'settings_url': 'العنوان الأساسي (Base URL)',
      'settings_key': 'مفتاح API',
      'settings_model': 'اسم النموذج',
      'settings_cancel': 'إلغاء',
      'settings_save': 'حفظ الإعدادات',
      'branch_ask_title': '🌿 إنشاء تفريع للمحادثة',
      'branch_context': 'السياق المحدد',
      'branch_question': 'سؤال التفريغ',
      'branch_input_hint': 'اطرح سؤالاً بناءً على هذا السياق...',
      'branch_route_banner': 'تم الانتقال إلى مسار السياق المتفرع',
      'branch_return_main': 'العودة للمسار الرئيسي',
      'toast_new_chat': 'تم بدء محادثة جديدة',
      'toast_branch_saved': '⭐ تم حفظ الرسالة في المفضلة بنجاح!',
      'toast_bookmark_removed': 'تم إزالة الرسالة من المفضلة',
      'toast_settings_saved': 'تم حفظ تهيئة واجهة API بنجاح!',
      'toast_import_success': 'تم استيراد البيانات ودمجها بنجاح!',
      'toast_export_success': 'تم تصدير البيانات بنجاح',
    }
  };

  // Look up the active language, fall back to Chinese, then to the key itself
  // so a missing translation degrades gracefully instead of crashing.
  String _t(String key) =>
      _translations[_currentLanguage]?[key] ??
      _translations['en']?[key] ??
      key;

  // Search bar controller (results/flags live in the cubit state).
  final TextEditingController _searchController = TextEditingController();

  // UI Controllers
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // API settings dialog controllers
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelNameController = TextEditingController();
  // Edge (local MNN) endpoint controllers.
  final TextEditingController _localBaseUrlController = TextEditingController();
  final TextEditingController _localModelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cubit = ChatCubit();
    // Surface cubit-originated messages (e.g. streaming errors) as toasts.
    _toastSub = _cubit.toasts.listen(_showToast);
    _cubit.init();
    // Demo-recording automation hook (web build only; no-op elsewhere).
    // Pass view-state callbacks so the driver can switch views via hooks instead
    // of clicking app-bar icons (whose positions move with UI redesigns).
    installDemoHooks(
      _cubit,
      setMindMap: (on) {
        setState(() => _isMindMapMode = on);
        if (!on) _cubit.loadLineage();
      },
      setDark: (on) => setState(() => _isDarkMode = on),
      triggerExport: _exportTreeMarkdown,
    );
  }

  @override
  void dispose() {
    _toastSub?.cancel();
    _cubit.close();
    _controller.dispose();
    _scrollController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelNameController.dispose();
    _localBaseUrlController.dispose();
    _localModelController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      // Re-check inside the callback: the widget may have been disposed (or the
      // list detached) during the delay, which would otherwise throw a
      // `_positions.isNotEmpty` assertion from animateTo on a dead controller.
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // --- ACTIONS ---

  void _stopStreaming() {
    if (_cubit.stopStreaming()) {
      _showToast(_t('toast_stopped'));
    }
  }

  // Point 2: Main Linear conversation step. Builds the message content
  // (including any attachment markdown) from UI state, then hands off to the
  // cubit which owns persistence + AI streaming.
  Future<void> _sendMessage(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty && _selectedFiles.isEmpty) return;
    if (_isStreaming || _isIngesting) return;

    // If the whole input is an arXiv/GitHub link (and nothing is attached),
    // offer to fetch it and build a multi-branch analysis tree instead of
    // sending the bare URL as a message.
    if (_selectedFiles.isEmpty) {
      final src = _cubit.detectIngestable(trimmedText);
      if (src != null) {
        _confirmIngest(trimmedText, src);
        return;
      }
    }

    _controller.clear();

    // Construct content with attachments
    String finalContent = trimmedText;
    if (_selectedFileNames.isNotEmpty) {
      final List<String> attachmentLinks = [];
      for (int i = 0; i < _selectedFiles.length; i++) {
        final file = _selectedFiles[i];
        final name = _selectedFileNames[i];
        attachmentLinks.add('📎 **[$name](${file.path})**');
      }
      final attachmentsMarkdown = attachmentLinks.join('\n');
      finalContent = finalContent.isEmpty
          ? attachmentsMarkdown
          : '$attachmentsMarkdown\n\n$finalContent';
    }

    // Clear file selection state
    setState(() {
      _selectedFiles.clear();
      _selectedFileNames.clear();
    });

    _cubit.sendMessage(finalContent);
  }

  // Point 1: Create a new branch question from a selected context text snippet
  Future<void> _createBranchQuestion(
      String sourceNodeId, String contextText, String question,
      {BackendMode? backend}) {
    return _cubit.createBranchQuestion(sourceNodeId, contextText, question,
        backend: backend);
  }

  // A recognized arXiv/GitHub link was entered — confirm, then fetch it and
  // grow a multi-branch analysis tree (the cubit drives the spinner + branches).
  Future<void> _confirmIngest(String url, DetectedSource src) async {
    final (String label, String what) = switch (src.kind) {
      SourceKind.arxiv => ('Analyze arXiv paper', 'this paper'),
      SourceKind.githubRepo => ('Analyze GitHub repo', 'this repository'),
      SourceKind.githubFile => ('Analyze file', 'this file'),
      SourceKind.unknown => ('Analyze', 'this link'),
    };
    final dark = _isDarkMode;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dark ? const Color(0xFF171717) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
              color: dark ? const Color(0xFF262626) : const Color(0xFFE2E2E2)),
        ),
        title: Row(
          children: [
            const Text('🌿 ', style: TextStyle(fontSize: 18)),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: dark ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        content: Text(
          'Dendrite will fetch $what and grow a multi-branch analysis tree from it.',
          style: TextStyle(
              color: dark ? const Color(0xFFB0B0B0) : const Color(0xFF555555),
              fontSize: 13.5,
              height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: TextStyle(
                    color:
                        dark ? const Color(0xFF888888) : const Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF10A37F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
            child: const Text('Analyze'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    _controller.clear();
    await _cubit.ingestUrl(url);
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result != null && result.files.isNotEmpty) {
        const int maxSizeBytes = 20 * 1024 * 1024; // 20MB limit
        final List<File> validFiles = [];
        final List<String> validNames = [];
        for (final file in result.files) {
          if (file.path != null) {
            if (file.size > maxSizeBytes) {
              _showToast('File ${file.name} exceeds the 20MB limit, skipped');
              continue;
            }
            validFiles.add(File(file.path!));
            validNames.add(file.name);
          }
        }
        if (validFiles.isNotEmpty) {
          setState(() {
            _selectedFiles.addAll(validFiles);
            _selectedFileNames.addAll(validNames);
          });
        }
      }
    } catch (e) {
      _showToast('Could not read file: $e');
    }
  }

  void _previewFile(String path, String name) async {
    final file = File(path);
    if (!await file.exists()) {
      _showToast('Cannot preview: the original file was moved or deleted');
      return;
    }
    if (!mounted) return;

    final isImg = name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.gif') || name.endsWith('.webp');
    final isTxt = name.endsWith('.txt') || name.endsWith('.json') || name.endsWith('.sql') || name.endsWith('.md') || name.endsWith('.dart');

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: _isDarkMode ? const Color(0xFF171717) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), 
            side: BorderSide(color: _isDarkMode ? const Color(0xFF262626) : const Color(0xFFE2E2E2)),
          ),
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: _isDarkMode ? Colors.white70 : Colors.black87, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Body content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: isImg
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            file,
                            fit: BoxFit.contain,
                          ),
                        )
                      : isTxt
                          ? FutureBuilder<String>(
                              future: file.readAsString(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator(color: Colors.grey));
                                }
                                if (snapshot.hasError) {
                                  return Text('Error reading text: ${snapshot.error}', style: const TextStyle(color: Colors.red));
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: snapshot.data ?? ''));
                                        _showToast('File content copied');
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.copy, size: 14, color: _isDarkMode ? Colors.white54 : Colors.black54),
                                          const SizedBox(width: 4),
                                          Text('Copy content', style: TextStyle(color: _isDarkMode ? Colors.white54 : Colors.black54, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _isDarkMode ? const Color(0xFF0D0D0D) : const Color(0xFFF9F9F9),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: _isDarkMode ? const Color(0xFF262626) : const Color(0xFFE2E2E2)),
                                      ),
                                      child: Text(
                                        snapshot.data ?? '',
                                        style: TextStyle(
                                          color: _isDarkMode ? Colors.white70 : Colors.black87,
                                          fontFamily: 'monospace',
                                          fontSize: 12.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.insert_drive_file, size: 64, color: _isDarkMode ? Colors.white54 : Colors.black54),
                                const SizedBox(height: 16),
                                Text(
                                  'This file type cannot be previewed directly',
                                  style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'File size: ${(file.lengthSync() / 1024).toStringAsFixed(1)} KB\nLocal path:\n$path',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // --- GLOBAL FULL-TEXT SEARCH ---
  Future<void> _performSearch(String query) => _cubit.performSearch(query);

  // --- IMPORT & EXPORT ---
  Future<void> _exportConversation() async {
    final path = await _cubit.exportConversation();
    _showToast(path != null ? '${_t('toast_export_success')}: $path' : 'Export failed');
  }

  Future<void> _exportTreeMarkdown() async {
    final result = await _cubit.exportTreeMarkdown();
    _showToast(result != null ? 'Markdown exported: $result' : 'Export failed');
  }

  Future<void> _importConversation() async {
    final result = await _cubit.importConversation();
    switch (result) {
      case ImportResult.success:
        _showToast(_t('toast_import_success'));
        break;
      case ImportResult.notFound:
        _showToast('No exported JSON backup file found — please export first!');
        break;
      case ImportResult.error:
        _showToast('Import failed');
        break;
    }
  }

  void _showToast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text, 
          style: TextStyle(
            color: _isDarkMode ? Colors.black : Colors.white, 
            fontSize: 12, 
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: _isDarkMode ? Colors.white : Colors.black,
        duration: Duration(milliseconds: kDemo ? 6000 : 1200),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 12, right: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- VIEW BUILDING ---

  @override
  Widget build(BuildContext context) {
    // Rebuild on every chat-state change; scroll to the latest content as the
    // lineage grows or streams. State is read via the getters above, which
    // resolve to this same cubit state inside the builder.
    return BlocConsumer<ChatCubit, ChatState>(
      bloc: _cubit,
      listener: (context, state) => _scrollToBottom(),
      builder: (context, state) => _buildScreen(),
    );
  }

  Widget _buildScreen() {
    if (!_isDbInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final themeBg = _isDarkMode ? const Color(0xFF0D0D0D) : const Color(0xFFFFFFFF);
    final themeText = _isDarkMode ? Colors.white : Colors.black;
    final themeSubText = _isDarkMode ? const Color(0xFFB4B4B4) : const Color(0xFF666666);
    final themeInputBg = _isDarkMode ? const Color(0xFF171717) : const Color(0xFFF4F4F4);
    final themeBorder = _isDarkMode ? const Color(0xFF262626) : const Color(0xFFE2E2E2);

    return Scaffold(
      backgroundColor: themeBg,
      // Left Drawer Sidebar containing Chat History, Global Search, and multi-API settings
      drawer: _buildLeftDrawer(themeBg, themeText, themeSubText, themeBorder),
      appBar: AppBar(
        backgroundColor: themeBg,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: themeSubText, size: 20),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        iconTheme: IconThemeData(color: themeSubText),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dendrite 1.0',
              style: TextStyle(
                color: themeText,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, color: themeSubText, size: 16),
          ],
        ),
        actions: [
          // Live Edge<->Cloud backend toggle (privacy/offline vs max capability).
          _buildModeChip(),
          // AppBar Switch: Toggle Dual-Mode view (Chat View <=> Infinite MindMap view)
          IconButton(
            icon: Icon(
              _isMindMapMode ? Icons.chat_bubble_outline : Icons.account_tree_outlined,
              color: _isDarkMode ? Colors.white : Colors.black,
              size: 22,
            ),
            onPressed: () {
              setState(() {
                _isMindMapMode = !_isMindMapMode;
              });
              if (!_isMindMapMode) {
                _cubit.loadLineage();
              }
            },
          ),
          // Export the whole tree to Markdown (feeds the slide-deck pipeline).
          IconButton(
            icon: Icon(Icons.ios_share, color: _isDarkMode ? Colors.white : Colors.black, size: 20),
            tooltip: 'Export tree to Markdown',
            onPressed: _exportTreeMarkdown,
          ),
          IconButton(
            icon: Icon(Icons.edit, color: _isDarkMode ? Colors.white : Colors.black, size: 20),
            onPressed: () {
              _cubit.newChat();
              _showToast(_t('toast_new_chat'));
            },
          ),
        ],
      ),
      body: _isMindMapMode
          ? MindMapCanvas(
              nodes: _allNodesInChat,
              activeNodeId: _activeNodeId ?? '',
              isDarkMode: _isDarkMode,
              onNodeTap: (nodeId) {
                setState(() {
                  _isMindMapMode = false;
                });
                _cubit.selectNode(nodeId);
              },
            )
          : Column(
              children: [
                Expanded(
                  child: _currentLineage.isEmpty
                      ? _buildEmptyState(themeText, themeSubText, themeBorder)
                      : _buildMessageList(themeText, themeSubText, themeBorder),
                ),
                _buildInputPill(themeText, themeSubText, themeInputBg, themeBorder),
              ],
            ),
    );
  }

  Widget _buildLeftDrawer(Color bg, Color textCol, Color subTextCol, Color borderCol) {
    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _isDarkMode ? Colors.white : Colors.black,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'D', 
                          style: TextStyle(
                            color: _isDarkMode ? Colors.black : Colors.white, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Dendrite 1.0',
                        style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Language Selector Dropdown
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: bg,
                          icon: Icon(Icons.language, color: subTextCol, size: 18),
                          value: _currentLanguage,
                          style: TextStyle(color: textCol, fontSize: 11, fontWeight: FontWeight.bold),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _currentLanguage = val;
                              });
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 'zh', child: Text('中文', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'en', child: Text('EN', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'fr', child: Text('FR', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'de', child: Text('DE', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'es', child: Text('ES', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'ja', child: Text('日本語', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'ko', child: Text('한국어', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'ru', child: Text('RU', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'ar', child: Text('العربية', style: TextStyle(fontSize: 11))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          _isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined,
                          color: subTextCol,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _isDarkMode = !_isDarkMode;
                          });
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),
            Divider(color: borderCol, height: 1),

            // Point 4: Global search bar across multiple chat histories
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              child: Container(
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF171717) : const Color(0xFFF4F4F4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderCol, width: 0.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(Icons.search, color: subTextCol, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: textCol, fontSize: 12),
                        onChanged: _performSearch,
                        decoration: InputDecoration(
                          hintText: _t('search_hint'),
                          hintStyle: TextStyle(color: subTextCol.withOpacity(0.5)),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Search results or historical chats list
            Expanded(
              child: _isSearching
                  ? _buildSearchResultsList(textCol, subTextCol)
                  : _buildHistoryAndBookmarksList(textCol, subTextCol),
            ),

            // Import, Export, & Multi-API Settings trigger footer
            Divider(color: borderCol, height: 1),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: Icon(Icons.download_rounded, color: _isDarkMode ? Colors.white70 : Colors.black87, size: 16),
                        label: Text(_t('backup_import'), style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87, fontSize: 11)),
                        onPressed: _importConversation,
                      ),
                      TextButton.icon(
                        icon: Icon(Icons.upload_rounded, color: _isDarkMode ? Colors.white70 : Colors.black87, size: 16),
                        label: Text(_t('backup_export'), style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87, fontSize: 11)),
                        onPressed: _exportConversation,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF2C2C2E),
                      child: Text('V', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    title: Text('Viktor', style: TextStyle(color: textCol, fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: Text(_t('developer_mode'), style: const TextStyle(color: Colors.grey, fontSize: 9)),
                    trailing: IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.grey, size: 20),
                      onPressed: () {
                        Navigator.pop(context); // Close drawer
                        _showApiSettingsDialog();
                      },
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsList(Color textCol, Color subTextCol) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text('No matching results', style: TextStyle(color: subTextCol, fontSize: 12)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _searchResults.length,
      itemBuilder: (ctx, idx) {
        final node = _searchResults[idx];
        return ListTile(
          dense: true,
          title: Text(node.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textCol, fontSize: 12)),
          subtitle: Text('ID: ${node.id} • ${node.role}', style: const TextStyle(color: Colors.grey, fontSize: 9)),
          leading: Icon(Icons.search, color: _isDarkMode ? Colors.white70 : Colors.black87, size: 16),
          onTap: () {
            _searchController.clear();
            _cubit.openSearchResult(node.chatId, node.id);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildHistoryAndBookmarksList(Color textCol, Color subTextCol) {
    // Collect bookmarked nodes from all nodes
    final bookmarkedNodes = _allNodesInChat.where((n) => n.isBookmarked).toList();

    return FutureBuilder<List<MapEntry<String, String>>>(
      future: _cubit.chatSessions(),
      builder: (context, snapshot) {
        final List<MapEntry<String, String>> sessions = snapshot.data ?? [
          const MapEntry('default_chat', 'Black Hole Event Horizon')
        ];

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          children: [
            if (bookmarkedNodes.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                child: Text(_t('bookmark_header'), style: const TextStyle(color: Color(0xFFFFB800), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              ...bookmarkedNodes.map((node) => ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: const Icon(Icons.star, color: Color(0xFFFFB800), size: 14),
                    title: Text(node.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textCol, fontSize: 11)),
                    onTap: () {
                      _cubit.selectNode(node.id);
                      Navigator.pop(context);
                      _showToast(_t('toast_jump_bookmark'));
                    },
                  )),
              Divider(color: _isDarkMode ? const Color(0xFF262626) : const Color(0xFFE2E2E2), height: 16),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: Text(_t('history_header'), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            ...sessions.map((session) {
              final isCurrent = session.key == _currentChatId;
              return ListTile(
                dense: true,
                selected: isCurrent,
                selectedColor: _isDarkMode ? Colors.white : Colors.black,
                selectedTileColor: kBrandAccent.withOpacity(_isDarkMode ? 0.12 : 0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.sm)),
                leading: Icon(
                  isCurrent ? Icons.chat_bubble : Icons.chat_bubble_outline,
                  color: isCurrent
                      ? (_isDarkMode ? kBrandAccentBright : kBrandAccent)
                      : (_isDarkMode ? Colors.white54 : Colors.black54),
                  size: 14,
                ),
                title: Text(
                  session.value,
                  style: TextStyle(
                    color: isCurrent ? textCol : textCol.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  _cubit.switchChat(session.key);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        );
      },
    );
  }

  // Multi-API Provider Gear panel config settings popup modal
  // Compact, tappable Edge/Cloud indicator for the AppBar (live switch).
  Widget _buildModeChip() {
    final isEdge = _cs.backendMode == BackendMode.edge;
    final color = isEdge
        ? kBrandAccent
        : (_isDarkMode ? Colors.white70 : Colors.black54);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _toggleBackendMode,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.5), width: 0.8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isEdge ? Icons.smartphone : Icons.cloud_outlined,
                size: 13, color: color),
            const SizedBox(width: 4),
            Text(_t(isEdge ? 'mode_edge' : 'mode_cloud'),
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  void _toggleBackendMode() {
    final next = _cs.backendMode == BackendMode.edge
        ? BackendMode.cloud
        : BackendMode.edge;
    _cubit.setBackendMode(next);
    _showToast(_t(next == BackendMode.edge ? 'toast_mode_edge' : 'toast_mode_cloud'));
  }

  void _showApiSettingsDialog() {
    // Sync controllers with current state before opening dialog
    _baseUrlController.text = _apiBaseUrl;
    _apiKeyController.text = _apiKey;
    _modelNameController.text = _apiModelName;
    _localBaseUrlController.text = _cs.localConfig.baseUrl;
    _localModelController.text = _cs.localConfig.modelName;
    // Local, dialog-scoped selections (committed to the cubit on save).
    String selectedProvider = _apiProvider;
    BackendMode selectedMode = _cs.backendMode;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF171717),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFF262626))),
          title: Row(
            children: [
              const Icon(Icons.settings_ethernet, color: Colors.white70, size: 22),
              const SizedBox(width: 8),
              Text(_t('settings_title'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Default backend (Edge / Cloud) toggle.
                Text(_t('settings_mode'), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final m in BackendMode.values)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedMode = m),
                          child: Container(
                            margin: EdgeInsets.only(right: m == BackendMode.edge ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selectedMode == m ? kBrandAccent.withOpacity(0.18) : const Color(0xFF0D0D0D),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: selectedMode == m ? kBrandAccent : const Color(0xFF262626)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(m == BackendMode.edge ? Icons.smartphone : Icons.cloud_outlined,
                                  size: 14, color: selectedMode == m ? kBrandAccentBright : Colors.grey),
                              const SizedBox(width: 6),
                              Text(_t(m == BackendMode.edge ? 'mode_edge_full' : 'mode_cloud_full'),
                                  style: TextStyle(
                                      color: selectedMode == m ? Colors.white : Colors.grey,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Dropdown selector
                Text(_t('settings_provider'), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0xFF0D0D0D), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF262626))),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: const Color(0xFF171717),
                      value: selectedProvider,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: const [
                        DropdownMenuItem(value: 'nvidia', child: Text('NVIDIA NIM API')),
                        DropdownMenuItem(value: 'xiaomi', child: Text('Xiaomi MiMo API')),
                        DropdownMenuItem(value: 'modelscope', child: Text('ModelScope API')),
                        DropdownMenuItem(value: 'openai', child: Text('OpenAI API')),
                        DropdownMenuItem(value: 'anthropic', child: Text('Anthropic API')),
                        DropdownMenuItem(value: 'gemini', child: Text('Gemini API')),
                        DropdownMenuItem(value: 'grok', child: Text('Grok API')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedProvider = val;
                            // Dynamically update standard endpoints & model names based on choice
                            final Map<String, Map<String, String>> defaults = {
                              'nvidia': { 'url': 'https://integrate.api.nvidia.com/v1', 'model': 'meta/llama-3.1-70b-instruct' },
                              'xiaomi': { 'url': 'https://api.mimo.xiaomi.com/v1', 'model': 'mimo-v3-chat' },
                              'modelscope': { 'url': 'https://api-inference.modelscope.cn/v1', 'model': 'Qwen/Qwen2.5-72B-Instruct' },
                              'openai': { 'url': 'https://api.openai.com/v1', 'model': 'gpt-4o' },
                              'anthropic': { 'url': 'https://api.anthropic.com/v1', 'model': 'claude-3-5-sonnet-20240620' },
                              'gemini': { 'url': 'https://generativelanguage.googleapis.com/v1beta', 'model': 'gemini-1.5-pro' },
                              'grok': { 'url': 'https://api.x.ai/v1', 'model': 'grok-beta' }
                            };
                            // Sync controllers so input fields reflect the new values
                            _baseUrlController.text = defaults[val]!['url']!;
                            _modelNameController.text = defaults[val]!['model']!;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Base URL Input
                Text(_t('settings_url'), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _buildDialogField(
                  controller: _baseUrlController,
                  hint: 'Base URL...',
                ),
                const SizedBox(height: 12),

                // API Key Input
                Text(_t('settings_key'), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _buildDialogField(
                  controller: _apiKeyController,
                  hint: 'API Key...',
                  obscureText: _obscureApiKey,
                  suffixIcon: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _obscureApiKey ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                      size: 18,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        _obscureApiKey = !_obscureApiKey;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Model name Input
                Text(_t('settings_model'), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _buildDialogField(
                  controller: _modelNameController,
                  hint: 'Model name...',
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF262626), height: 1),
                const SizedBox(height: 14),

                // Edge (local MNN) endpoint — used when the Edge backend is active.
                Row(children: [
                  const Icon(Icons.smartphone, color: Color(0xFF19C37D), size: 14),
                  const SizedBox(width: 6),
                  Text(_t('settings_local_title'),
                      style: const TextStyle(color: Color(0xFF19C37D), fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 10),
                Text(_t('settings_local_url'), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _buildDialogField(
                  controller: _localBaseUrlController,
                  hint: 'http://<host>:8080/v1',
                ),
                const SizedBox(height: 12),
                Text(_t('settings_local_model'), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _buildDialogField(
                  controller: _localModelController,
                  hint: 'Qwen3-1.7B-MNN',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('settings_cancel'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDarkMode ? Colors.white : Colors.black, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                // Commit cloud + edge configs and the default backend mode.
                _cubit.updateConfig(ApiConfig(
                  provider: selectedProvider,
                  baseUrl: _baseUrlController.text.trim(),
                  apiKey: _apiKeyController.text.trim(),
                  modelName: _modelNameController.text.trim(),
                ));
                _cubit.updateLocalConfig(_cs.localConfig.copyWith(
                  provider: 'mnn',
                  baseUrl: _localBaseUrlController.text.trim(),
                  modelName: _localModelController.text.trim(),
                  apiKey: 'sk-local',
                ));
                _cubit.setBackendMode(selectedMode);
                Navigator.pop(context);
                _showToast(_t('toast_settings_saved'));
              },
              child: Text(
                _t('settings_save'),
                style: TextStyle(
                  color: _isDarkMode ? Colors.black : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0D0D0D), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF262626))),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        textAlignVertical: TextAlignVertical.center, // Keep text vertically centered!
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
          border: InputBorder.none,
          suffixIcon: suffixIcon,
          suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          contentPadding: const EdgeInsets.symmetric(vertical: 14), // Uniform vertical padding!
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textCol, Color subTextCol, Color borderCol) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Neural visual logo — accent-tinted halo reinforces the "branch" identity.
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    kBrandAccent.withOpacity(_isDarkMode ? 0.22 : 0.14),
                    kBrandAccent.withOpacity(0.0),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: kBrandAccent.withOpacity(0.35), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: kBrandAccent.withOpacity(_isDarkMode ? 0.30 : 0.18),
                    blurRadius: 28,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(38, 38),
                  painter: DendriteLogoPainter(color: kBrandAccent),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              _t('welcome_title'),
              style: TextStyle(
                color: textCol,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t('welcome_subtitle'),
              style: TextStyle(
                color: _isDarkMode ? const Color(0xFF8E8E8F) : const Color(0xFF8A8A8A),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 34),
            
            // Quick start capsules
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.4,
              children: [
                _buildPromptCard('🌿 解释一下黑洞的"事件视界"', '从黑洞开始，展开分支提问', borderCol),
                _buildPromptCard('💡 头脑风暴一个科幻故事的支线', '拆分出多条故事线', borderCol),
                _buildPromptCard('🧠 设计一个树状对话的本地数据库', '用 Drift + SQLite 递归查询', borderCol),
                _buildPromptCard('✍️ 畅想这个应用的核心价值', '体验树状对话的力量', borderCol),
              ],
            )
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildPromptCard(String title, String subtitle, Color borderCol) {
    final cardFill = _isDarkMode ? const Color(0xFF141414) : const Color(0xFFFAFAFA);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(R.lg),
      child: InkWell(
        onTap: () {
          _controller.text = title.substring(2); // Strip emoji
        },
        borderRadius: BorderRadius.circular(R.lg),
        splashColor: kBrandAccent.withOpacity(0.10),
        highlightColor: kBrandAccent.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: cardFill,
            borderRadius: BorderRadius.circular(R.lg),
            border: Border.all(color: borderCol, width: 1.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accent leading bar ties the card to the brand branch colour.
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: kBrandAccent.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _isDarkMode ? const Color(0xFF8E8E8F) : const Color(0xFF9A9A9A),
                        fontSize: 9.5,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(Color textCol, Color subTextCol, Color borderCol) {
    return _centered(ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      itemCount: _currentLineage.length,
      itemBuilder: (context, index) {
        final node = _currentLineage[index];
        final isUser = node.role == 'user';

        if (isUser) {
          final attachments = _parseAttachments(node.content);
          final cleanContent = _cleanContentOfAttachments(node.content);

          return GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: cleanContent));
              _showToast(_t('toast_copied'));
            },
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF171717) : const Color(0xFFF4F4F4),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(color: borderCol, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Clickable attachments
                  if (attachments.isNotEmpty) ...[
                    ...attachments.map((att) {
                      final isImg = att.name.endsWith('.png') || att.name.endsWith('.jpg') || att.name.endsWith('.jpeg') || att.name.endsWith('.gif') || att.name.endsWith('.webp');
                      return GestureDetector(
                        onTap: () => _previewFile(att.path, att.name),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isDarkMode ? const Color(0x1AFFFFFF) : const Color(0x0D000000),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isDarkMode ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isImg ? Icons.image : Icons.insert_drive_file,
                                size: 16,
                                color: _isDarkMode ? Colors.white : Colors.black,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  att.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _isDarkMode ? Colors.white : Colors.black,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (cleanContent.isNotEmpty) const SizedBox(height: 4),
                  ],
                  if (cleanContent.isNotEmpty)
                    Text(
                      cleanContent,
                      style: TextStyle(color: textCol, fontSize: 14.5, height: 1.5),
                    ),
                ],
              ),
            ),
          ),
          );
        } else {
          // Flat editorial style AI message - No speech bubble!
          // Show animated thinking indicator when content is empty and streaming
          if (node.content.isEmpty && _isStreaming) {
            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: _buildThinkingIndicator(textCol),
            );
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Point 1: CustomSelectionMenu wrapper wrapping text bubble itself
                CustomSelectionMenu(
                  onBranchAsk: (selectedText) {
                    _showBranchAskDrawer(node.id, selectedText, textCol, subTextCol);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: _buildRichMessageContent(node, textCol),
                  ),
                ),
                // Small action toolbar at the bottom right of the AI message card
                Padding(
                  padding: const EdgeInsets.only(right: 4.0, top: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.copy,
                          color: Colors.grey,
                          size: 15,
                        ),
                        onPressed: () {
                          final parsed = _parseThinkingProcess(node.content);
                          final copyText = parsed.content.replaceAll(r'\n', '\n').trim();
                          Clipboard.setData(ClipboardData(text: copyText));
                          _showToast(_t('toast_copied'));
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          node.isBookmarked ? Icons.star : Icons.star_border,
                          color: node.isBookmarked ? const Color(0xFFFFB800) : Colors.grey,
                          size: 16,
                        ),
                        onPressed: () {
                          _showToast(!node.isBookmarked ? _t('toast_branch_saved') : _t('toast_bookmark_removed'));
                          _cubit.toggleBookmark(node);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      },
    ));
  }

  Widget _buildThinkingIndicator(Color textCol) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThinkingDots(color: _isDarkMode ? kBrandAccentBright : kBrandAccent),
          const SizedBox(width: 10),
          Text(
            _t('thinking_active'),
            style: TextStyle(
              color: _isDarkMode ? kBrandAccentBright : kBrandAccent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Point 3: Highlight previously branched words and handle tap navigation
  Widget _buildRichMessageContent(Message node, Color textCol) {
    final parsed = _parseThinkingProcess(node.content);
    // CRITICAL FIX: Replace literal backslash-n sequences with real newlines to enable correct Markdown rendering!
    final text = parsed.content.replaceAll(r'\n', '\n');

    // While this node is actively streaming, render plain text: feeding partial
    // markdown (unclosed **, `, [ ...) to flutter_markdown trips an internal
    // `_inlines.isEmpty` assertion. Switch to rich markdown once it completes.
    final isStreamingNode = _isStreaming &&
        _currentLineage.isNotEmpty &&
        _currentLineage.last.id == node.id;
    if (isStreamingNode) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(text,
            style: TextStyle(color: textCol, fontSize: 14.5, height: 1.5)),
      );
    }

    // Find if this node has any branched children
    final branchedChildren = _allNodesInChat.where((n) => n.parentId == node.id && n.associatedSelection != null).toList();

    final subTextCol = _isDarkMode ? const Color(0xFFB4B4B4) : const Color(0xFF666666);

    final markdownStyle = MarkdownStyleSheet(
      p: TextStyle(color: textCol, fontSize: 14.5, height: 1.6, letterSpacing: 0.1),
      h1: TextStyle(color: textCol, fontSize: 20.0, fontWeight: FontWeight.bold, height: 1.5),
      h2: TextStyle(color: textCol, fontSize: 18.0, fontWeight: FontWeight.bold, height: 1.5),
      h3: TextStyle(color: textCol, fontSize: 16.0, fontWeight: FontWeight.bold, height: 1.5),
      code: TextStyle(
        color: _isDarkMode ? const Color(0xFFE2E2E2) : const Color(0xFF262626),
        backgroundColor: _isDarkMode ? const Color(0xFF262626) : const Color(0xFFF4F4F4),
        fontFamily: 'monospace',
        fontSize: 13.0,
      ),
      codeblockPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      codeblockDecoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF171717) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _isDarkMode ? const Color(0xFF262626) : const Color(0xFFE2E2E2), width: 0.8),
      ),
      blockquoteDecoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
        border: Border(left: BorderSide(color: _isDarkMode ? Colors.white38 : Colors.black38, width: 4)),
      ),
      blockquote: TextStyle(color: subTextCol, fontStyle: FontStyle.italic),
      tableHead: TextStyle(color: textCol, fontSize: 13.5, fontWeight: FontWeight.bold),
      tableBody: TextStyle(color: textCol, fontSize: 13.0, height: 1.4),
      tableBorder: TableBorder.all(color: _isDarkMode ? const Color(0x33FFFFFF) : const Color(0x1F000000), width: 0.8),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );

    Widget buildMainContent() {
      if (branchedChildren.isEmpty) {
        return ScrollConfiguration(
          behavior: NoScrollbarBehavior(),
          child: MarkdownBody(
            data: text,
            extensionSet: md.ExtensionSet.gitHubFlavored,
            styleSheet: markdownStyle,
            builders: {
              'pre': CodeBlockMarkdownElementBuilder(
                isDarkMode: _isDarkMode,
                textCol: textCol,
              ),
            },
          ),
        );
      }

      // High fidelity rich text parser matching substrings
      final List<_HighlightSegment> segments = [];
      
      for (final child in branchedChildren) {
        final highlightText = child.associatedSelection!;
        int idx = -1;
        while (true) {
          idx = text.indexOf(highlightText, idx + 1);
          if (idx == -1) break;

          final end = idx + highlightText.length;
          bool overlaps = false;
          for (final seg in segments) {
            if (!(end <= seg.start || idx >= seg.end)) {
              overlaps = true;
              break;
            }
          }
          if (!overlaps) {
            segments.add(_HighlightSegment(idx, end, child));
            break; // Found a valid non-overlapping position for this child!
          }
        }
      }

      // Sort segments by their starting position in text to parse them in visual order
      segments.sort((a, b) => a.start.compareTo(b.start));

      final List<InlineSpan> inlineSpans = [];
      int lastIdx = 0;

      for (final seg in segments) {
        if (seg.start > lastIdx) {
          final rawPart = text.substring(lastIdx, seg.start);
          inlineSpans.add(TextSpan(text: rawPart));
        }

        // Branching visually emphasized inline badge widget embedded as an Inline WidgetSpan!
        inlineSpans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () {
                final deepestId = ChatTree.deepestDescendant(seg.child.id, _allNodesInChat);
                _cubit.openBranch(deepestId);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: kBrandAccent.withOpacity(_isDarkMode ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(R.sm),
                  border: Border.all(color: kBrandAccent.withOpacity(0.45), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.alt_route, size: 11, color: _isDarkMode ? kBrandAccentBright : kBrandAccent),
                    const SizedBox(width: 4),
                    Text(
                      text.substring(seg.start, seg.end),
                      style: TextStyle(
                        color: _isDarkMode ? kBrandAccentBright : kBrandAccent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        lastIdx = seg.end;
      }

      if (lastIdx < text.length) {
        final rawPart = text.substring(lastIdx);
        inlineSpans.add(TextSpan(text: rawPart));
      }

      return RichText(
        text: TextSpan(
          style: TextStyle(color: textCol, fontSize: 14.5, height: 1.6, letterSpacing: 0.1),
          children: inlineSpans,
        ),
      );
    }

    // Wrap in thinking block if thinking exists
    if (parsed.thinking != null) {
      final isExpanded = !parsed.isThinkingComplete || _expandedThinkingNodeIds.contains(node.id);
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (parsed.isThinkingComplete) {
                setState(() {
                  if (_expandedThinkingNodeIds.contains(node.id)) {
                    _expandedThinkingNodeIds.remove(node.id);
                  } else {
                    _expandedThinkingNodeIds.add(node.id);
                  }
                });
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isDarkMode ? const Color(0xFF2D2D2D) : const Color(0xFFEFEFEF),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    parsed.isThinkingComplete
                        ? (isExpanded ? Icons.psychology_outlined : Icons.psychology)
                        : Icons.insights,
                    size: 16,
                    color: parsed.isThinkingComplete
                        ? (_isDarkMode ? Colors.white70 : Colors.black87)
                        : (_isDarkMode ? kBrandAccentBright : kBrandAccent),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    parsed.isThinkingComplete
                        ? (isExpanded ? 'Reasoning (tap to collapse)' : 'Reasoning complete (tap to view)')
                        : 'Thinking deeply...',
                    style: TextStyle(
                      color: parsed.isThinkingComplete
                          ? (_isDarkMode ? Colors.white70 : Colors.black87)
                          : (_isDarkMode ? kBrandAccentBright : kBrandAccent),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (parsed.isThinkingComplete) ...[
                    const SizedBox(width: 6),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 14,
                      color: _isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              margin: const EdgeInsets.only(left: 6, bottom: 16),
              padding: const EdgeInsets.only(left: 14, top: 4, bottom: 4),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: kBrandAccent.withOpacity(_isDarkMode ? 0.45 : 0.30),
                    width: 1.5,
                  ),
                ),
              ),
              child: Text(
                parsed.thinking!.replaceAll(r'\n', '\n'),
                style: TextStyle(
                  color: _isDarkMode ? const Color(0xFF8E8E8F) : const Color(0xFF6E6E6F),
                  fontSize: 13.5,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (text.isNotEmpty) buildMainContent(),
        ],
      );
    }

    return buildMainContent();
  }

  // Point 1 & Point 3: Slide up custom branching bottom sheet drawer
  void _showBranchAskDrawer(String sourceNodeId, String selectedText, Color textCol, Color subTextCol) {
    final TextEditingController branchController = TextEditingController();
    BackendMode? branchBackend; // null = follow the current default mode

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF9F9F9),
            border: Border(top: BorderSide(color: _isDarkMode ? const Color(0xFF262626) : const Color(0xFFE2E2E2), width: 1.0)),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF333333) : const Color(0xFFCCCCCC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.call_split, color: Colors.grey, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _t('branch_ask_title'),
                    style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: -0.2),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Context preview blockquote
              Text(_t('branch_context'), style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF080808) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isDarkMode ? const Color(0xFF262626) : const Color(0xFFE2E2E2)),
                ),
                child: Text(
                  '“$selectedText”',
                  style: TextStyle(color: subTextCol, fontSize: 12.5, height: 1.4, fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 16),

              // Per-branch engine router: this branch can run on a different
              // backend than the trunk (null = follow the default mode).
              Text(_t('branch_engine'), style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final opt in <({String label, BackendMode? mode})>[
                    (label: _t('branch_engine_default'), mode: null),
                    (label: _t('mode_edge'), mode: BackendMode.edge),
                    (label: _t('mode_cloud'), mode: BackendMode.cloud),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setSheet(() => branchBackend = opt.mode),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: branchBackend == opt.mode ? kBrandAccent.withOpacity(0.18) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: branchBackend == opt.mode ? kBrandAccent : (_isDarkMode ? const Color(0xFF333333) : const Color(0xFFD9D9D9))),
                          ),
                          child: Text(opt.label,
                              style: TextStyle(
                                  color: branchBackend == opt.mode ? kBrandAccentBright : subTextCol,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Question input pill
              Text(_t('branch_question'), style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF171717) : Colors.white,
                  border: Border.all(color: _isDarkMode ? const Color(0xFF262626) : const Color(0xFFE2E2E2)),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: branchController,
                        style: TextStyle(color: textCol, fontSize: 13.5),
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: _t('branch_input_hint'),
                          hintStyle: TextStyle(color: subTextCol.withOpacity(0.5)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final question = branchController.text;
                        if (question.isNotEmpty) {
                          Navigator.pop(ctx);
                          _createBranchQuestion(sourceNodeId, selectedText, question,
                              backend: branchBackend);
                        }
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _isDarkMode ? Colors.white : Colors.black, 
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_upward, 
                          size: 14, 
                          color: _isDarkMode ? Colors.black : Colors.white,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildInputPill(Color textCol, Color subTextCol, Color inputBg, Color borderCol) {
    return _centered(Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 8),
      child: Column(
        children: [
          // Branched banner trigger
          if (_currentLineage.any((m) => m.associatedSelection != null))
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: kBrandAccent.withOpacity(_isDarkMode ? 0.14 : 0.09),
                borderRadius: BorderRadius.circular(R.md),
                border: Border.all(color: kBrandAccent.withOpacity(0.40)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_tree, color: _isDarkMode ? kBrandAccentBright : kBrandAccent, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _t('branch_route_banner'),
                        style: TextStyle(color: _isDarkMode ? kBrandAccentBright : kBrandAccent, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _cubit.returnToParentBranch(),
                    child: Text(
                      _t('branch_return_parent'),
                      style: TextStyle(
                        color: _isDarkMode ? kBrandAccentBright : kBrandAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                ],
              ),
            ),

          // Picked Files display
          if (_selectedFileNames.isNotEmpty)
            Container(
              height: 38,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedFileNames.length,
                itemBuilder: (context, idx) {
                  final name = _selectedFileNames[idx];
                  final isImg = name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.gif') || name.endsWith('.webp');
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isDarkMode ? const Color(0xFF2D2D2D) : const Color(0xFFE5E5EA),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isImg ? Icons.image : Icons.insert_drive_file,
                          size: 14,
                          color: _isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          name.length > 18 ? '${name.substring(0, 10)}...${name.substring(name.length - 6)}' : name,
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedFiles.removeAt(idx);
                              _selectedFileNames.removeAt(idx);
                            });
                          },
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: _isDarkMode ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Main input pill
          Container(
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(R.pill),
              border: Border.all(color: borderCol, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: _isDarkMode
                      ? Colors.black.withOpacity(0.35)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickFiles,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                    child: Text(
                      '+',
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (kE2E)
                  Offstage(
                    child: Text(
                      _currentLineage
                              .where((m) => m.role == 'assistant')
                              .isEmpty
                          ? ''
                          : _currentLineage
                              .lastWhere((m) => m.role == 'assistant')
                              .content,
                      key: const Key('assistant-latest'),
                    ),
                  ),
                if (kE2E)
                  Offstage(
                    child: Text(
                      'nodes=${_allNodesInChat.length};'
                      'assistant=${_allNodesInChat.where((m) => m.role == 'assistant' && m.content.trim().isNotEmpty).length};'
                      'branches=${_allNodesInChat.where((m) => m.associatedSelection != null).length}',
                      key: const Key('tree-summary'),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    key: const Key('composer-input'),
                    controller: _controller,
                    style: TextStyle(color: textCol, fontSize: 14.5),
                    onSubmitted: _sendMessage,
                    decoration: InputDecoration(
                      hintText: _t('input_hint'),
                      hintStyle: TextStyle(color: subTextCol.withOpacity(0.5)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                GestureDetector(
                  key: const Key('send-button'),
                  onTap: _isIngesting
                      ? null
                      : (_isStreaming
                          ? _stopStreaming
                          : () => _sendMessage(_controller.text)),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _isIngesting
                          ? const Color(0xFF10A37F)
                          : (_isStreaming
                              ? const Color(0xFFCC3333)
                              : (_isDarkMode ? Colors.white : Colors.black)),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: _isIngesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            _isStreaming ? Icons.stop : Icons.arrow_upward,
                            color: Colors.white,
                            size: 16,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}

class DendriteLogoPainter extends CustomPainter {
  final Color color;
  DendriteLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);

    final nodePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, nodePaint);

    canvas.drawLine(center, Offset(center.dx - 12, center.dy - 12), paint);
    canvas.drawLine(center, Offset(center.dx + 12, center.dy - 8), paint);
    canvas.drawLine(center, Offset(center.dx - 4, center.dy + 14), paint);

    canvas.drawLine(Offset(center.dx - 12, center.dy - 12), Offset(center.dx - 18, center.dy - 10), paint);
    canvas.drawLine(Offset(center.dx - 12, center.dy - 12), Offset(center.dx - 14, center.dy - 18), paint);
    canvas.drawLine(Offset(center.dx + 12, center.dy - 8), Offset(center.dx + 18, center.dy - 16), paint);
    canvas.drawLine(Offset(center.dx + 12, center.dy - 8), Offset(center.dx + 16, center.dy + 2), paint);

    canvas.drawCircle(Offset(center.dx - 18, center.dy - 10), 1.5, nodePaint);
    canvas.drawCircle(Offset(center.dx - 14, center.dy - 18), 1.5, nodePaint);
    canvas.drawCircle(Offset(center.dx + 18, center.dy - 16), 1.5, nodePaint);
    canvas.drawCircle(Offset(center.dx + 16, center.dy + 2), 1.5, nodePaint);
    canvas.drawCircle(Offset(center.dx - 4, center.dy + 14), 2.0, nodePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HighlightSegment {
  final int start;
  final int end;
  final Message child;
  _HighlightSegment(this.start, this.end, this.child);
}

class _ThinkingParsed {
  final String? thinking;
  final String content;
  final bool isThinkingComplete;

  _ThinkingParsed({
    this.thinking,
    required this.content,
    required this.isThinkingComplete,
  });
}

_ThinkingParsed _parseThinkingProcess(String text) {
  if (!text.contains('<think>')) {
    return _ThinkingParsed(content: text, isThinkingComplete: true);
  }

  final startIdx = text.indexOf('<think>');
  final thinkStart = startIdx + 7;

  if (text.contains('</think>')) {
    final endIdx = text.indexOf('</think>');
    final thinking = text.substring(thinkStart, endIdx).trim();
    final content = text.substring(endIdx + 8).trim();
    return _ThinkingParsed(
      thinking: thinking.isNotEmpty ? thinking : null,
      content: content,
      isThinkingComplete: true,
    );
  } else {
    // Thinking is still in progress (streaming)
    final thinking = text.substring(thinkStart).trim();
    return _ThinkingParsed(
      thinking: thinking.isNotEmpty ? thinking : null,
      content: '',
      isThinkingComplete: false,
    );
  }
}

class _ParsedAttachment {
  final String name;
  final String path;
  _ParsedAttachment(this.name, this.path);
}

List<_ParsedAttachment> _parseAttachments(String content) {
  final List<_ParsedAttachment> list = [];
  final regex = RegExp(r'📎 \*\*\[([^\]]+)\]\(([^)]+)\)\*\*');
  final matches = regex.allMatches(content);
  for (final match in matches) {
    final name = match.group(1);
    final path = match.group(2);
    if (name != null && path != null) {
      list.add(_ParsedAttachment(name, path));
    }
  }
  return list;
}

String _cleanContentOfAttachments(String content) {
  final regex = RegExp(r'📎 \*\*\[([^\]]+)\]\(([^)]+)\)\*\*\n?');
  return content.replaceAll(regex, '').trim();
}

class NoScrollbarBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class _ThinkingDots extends StatefulWidget {
  final Color color;
  const _ThinkingDots({required this.color});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = (t + i * 0.33) % 1.0;
            final bounce = (offset * 3.14159 * 2).abs();
            final dy = -8 * (bounce < 1.57 ? bounce / 1.57 : (3.14159 - bounce) / 1.57);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class CodeBlockMarkdownElementBuilder extends MarkdownElementBuilder {
  final bool isDarkMode;
  final Color textCol;

  CodeBlockMarkdownElementBuilder({required this.isDarkMode, required this.textCol});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF171717) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDarkMode ? const Color(0xFF262626) : const Color(0xFFE2E2E2), width: 0.8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          text,
          style: TextStyle(
            color: isDarkMode ? const Color(0xFFE2E2E2) : const Color(0xFF262626),
            fontFamily: 'monospace',
            fontSize: 13.0,
          ),
        ),
      ),
    );
  }
}
