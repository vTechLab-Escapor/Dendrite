/// Immutable configuration for the AI provider/endpoint.
class ApiConfig {
  final String provider;
  final String baseUrl;
  final String apiKey;
  final String modelName;

  const ApiConfig({
    required this.provider,
    required this.baseUrl,
    required this.apiKey,
    required this.modelName,
  });

  ApiConfig copyWith({
    String? provider,
    String? baseUrl,
    String? apiKey,
    String? modelName,
  }) {
    return ApiConfig(
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
    );
  }
}
