import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dendrite/core/models/api_config.dart';

/// Persists [ApiConfig]. Non-sensitive fields live in a JSON file in the app
/// documents directory; the API key lives in the platform secure store
/// (Keychain/Keystore). Handles first-run defaults and legacy migrations.
class SettingsRepository {
  static const String _apiKeyStorageKey = 'dendrite_api_key';
  static const String _fileName = 'dendrite_settings.json';

  // Keys injected at compile time via --dart-define.
  static const String _nvKeyInjected =
      String.fromEnvironment('NVIDIA_API_KEY', defaultValue: '');
  static const String _msKeyInjected =
      String.fromEnvironment('MODELSCOPE_API_KEY', defaultValue: '');

  final FlutterSecureStorage _secureStorage;

  SettingsRepository({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// Defaults derived from compile-time keys (NVIDIA preferred, then ModelScope).
  ApiConfig defaults() {
    if (_nvKeyInjected.isNotEmpty) {
      return const ApiConfig(
        provider: 'nvidia',
        baseUrl: 'https://integrate.api.nvidia.com/v1',
        apiKey: _nvKeyInjected,
        modelName: 'meta/llama-3.1-70b-instruct',
      );
    } else if (_msKeyInjected.isNotEmpty) {
      return const ApiConfig(
        provider: 'modelscope',
        baseUrl: 'https://api-inference.modelscope.cn/v1',
        apiKey: _msKeyInjected,
        modelName: 'Qwen/Qwen2.5-72B-Instruct',
      );
    }
    return const ApiConfig(
      provider: 'nvidia',
      baseUrl: 'https://integrate.api.nvidia.com/v1',
      apiKey: '',
      modelName: 'meta/llama-3.1-70b-instruct',
    );
  }

  Future<ApiConfig> load() async {
    final defaultConfig = defaults();
    try {
      final secureKey = await _secureStorage.read(key: _apiKeyStorageKey);
      final file = await _file();

      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        // Legacy installs stored the key in plaintext JSON; the save() below
        // migrates it into secure storage and strips it from the file.
        final legacyKey = data['api_key'] as String?;
        final resolvedKey = (secureKey != null && secureKey.isNotEmpty)
            ? secureKey
            : ((legacyKey != null && legacyKey.isNotEmpty)
                ? legacyKey
                : defaultConfig.apiKey);

        final loaded = ApiConfig(
          provider: data['provider'] ?? defaultConfig.provider,
          baseUrl: data['base_url'] ?? defaultConfig.baseUrl,
          apiKey: resolvedKey,
          modelName: data['model_name'] ?? defaultConfig.modelName,
        );

        final migrated = _migrate(loaded, defaultConfig);
        await save(migrated); // strips plaintext key + persists migrated values
        return migrated;
      }

      // First-time load: pre-populate with defaults. A key may still exist in
      // secure storage (e.g. after a reinstall on iOS), so prefer it.
      final config = defaultConfig.copyWith(
        apiKey: (secureKey != null && secureKey.isNotEmpty)
            ? secureKey
            : defaultConfig.apiKey,
      );
      await save(config);
      return config;
    } catch (_) {
      return defaultConfig;
    }
  }

  /// Applies historical config fixups (deprecated endpoints/models).
  ApiConfig _migrate(ApiConfig config, ApiConfig defaultConfig) {
    var provider = config.provider;
    var baseUrl = config.baseUrl;
    var modelName = config.modelName;
    var apiKey = config.apiKey;

    // Force-upgrade any old/incorrect ModelScope endpoints.
    if (baseUrl == 'https://api.modelscope.cn/v1') {
      baseUrl = 'https://api-inference.modelscope.cn/v1';
    }

    // Force-upgrade any old/incorrect MiniMax-M2.7 configurations to Nvidia.
    if (modelName == 'MiniMax/MiniMax-M2.7' && provider == 'modelscope') {
      provider = 'nvidia';
      baseUrl = 'https://integrate.api.nvidia.com/v1';
      modelName = 'meta/llama-3.1-70b-instruct';
      if (_nvKeyInjected.isNotEmpty) {
        apiKey = _nvKeyInjected;
      }
    }

    // Force-upgrade any EOL/deprecated Nvidia models.
    if (modelName == 'minimaxai/minimax-m2.7' ||
        modelName == 'minimaxai/minimax-m2.5' ||
        modelName == 'meta/llama-3-70b-instruct' ||
        modelName == 'nvidia/llama-3.1-nemotron-70b-instruct') {
      modelName = 'meta/llama-3.1-70b-instruct';
    }

    // If the key is empty but a compile-time key exists, adopt the full defaults.
    if (apiKey.isEmpty && defaultConfig.apiKey.isNotEmpty) {
      return defaultConfig;
    }

    return ApiConfig(
      provider: provider,
      baseUrl: baseUrl,
      apiKey: apiKey,
      modelName: modelName,
    );
  }

  Future<void> save(ApiConfig config) async {
    try {
      final file = await _file();
      // Non-sensitive config goes to the JSON file; the API key never does.
      await file.writeAsString(jsonEncode({
        'provider': config.provider,
        'base_url': config.baseUrl,
        'model_name': config.modelName,
      }));
      // Persist the API key in the platform secure store.
      if (config.apiKey.isEmpty) {
        await _secureStorage.delete(key: _apiKeyStorageKey);
      } else {
        await _secureStorage.write(key: _apiKeyStorageKey, value: config.apiKey);
      }
    } catch (_) {}
  }
}
