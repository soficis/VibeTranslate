/// Clean Code domain entities with meaningful names and immutability
/// Following Domain-Driven Design principles
library;

/// Represents a translation request with clear, meaningful naming
class TranslationRequest {
  final String text;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime timestamp;

  TranslationRequest({
    required this.text,
    required this.sourceLanguage,
    required this.targetLanguage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a copy with modified fields
  TranslationRequest copyWith({
    String? text,
    String? sourceLanguage,
    String? targetLanguage,
    DateTime? timestamp,
  }) {
    return TranslationRequest(
      text: text ?? this.text,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationRequest &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          sourceLanguage == other.sourceLanguage &&
          targetLanguage == other.targetLanguage;

  @override
  int get hashCode =>
      text.hashCode ^ sourceLanguage.hashCode ^ targetLanguage.hashCode;

  @override
  String toString() {
    return 'TranslationRequest(text: ${text.substring(0, text.length > 50 ? 50 : text.length)}..., '
        'source: $sourceLanguage, target: $targetLanguage, timestamp: $timestamp)';
  }
}

/// Represents a translation result with clear success/failure states
class TranslationResult {
  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime timestamp;
  final int characterCount;

  TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    DateTime? timestamp,
    int? characterCount,
  })  : timestamp = timestamp ?? DateTime.now(),
        characterCount = characterCount ?? translatedText.length;

  /// Create a copy with modified fields
  TranslationResult copyWith({
    String? originalText,
    String? translatedText,
    String? sourceLanguage,
    String? targetLanguage,
    DateTime? timestamp,
    int? characterCount,
  }) {
    return TranslationResult(
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      timestamp: timestamp ?? this.timestamp,
      characterCount: characterCount ?? this.characterCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationResult &&
          runtimeType == other.runtimeType &&
          originalText == other.originalText &&
          translatedText == other.translatedText &&
          sourceLanguage == other.sourceLanguage &&
          targetLanguage == other.targetLanguage;

  @override
  int get hashCode =>
      originalText.hashCode ^
      translatedText.hashCode ^
      sourceLanguage.hashCode ^
      targetLanguage.hashCode;

  @override
  String toString() {
    return 'TranslationResult(original: ${originalText.substring(0, originalText.length > 30 ? 30 : originalText.length)}..., '
        'translated: ${translatedText.substring(0, translatedText.length > 30 ? 30 : translatedText.length)}..., '
        'source: $sourceLanguage, target: $targetLanguage, chars: $characterCount)';
  }
}

/// Represents the complete backtranslation result (English -> Japanese -> English)
class BackTranslationResult {
  final String originalText;
  final TranslationResult intermediateTranslation;
  final TranslationResult finalTranslation;
  final DateTime timestamp;
  final Duration totalDuration;

  BackTranslationResult({
    required this.originalText,
    required this.intermediateTranslation,
    required this.finalTranslation,
    required this.timestamp,
    required this.totalDuration,
  });

  /// Get the final backtranslated text
  String get backTranslatedText => finalTranslation.translatedText;

  /// Calculate accuracy score (simple character-based similarity)
  double get similarityScore {
    final original =
        originalText.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final backTranslated =
        backTranslatedText.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');

    if (original.isEmpty || backTranslated.isEmpty) return 0;

    final originalWords = original.split(RegExp(r'\s+'));
    final backTranslatedWords = backTranslated.split(RegExp(r'\s+'));

    final commonWords =
        originalWords.where(backTranslatedWords.contains).length;
    return commonWords / originalWords.length;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackTranslationResult &&
          runtimeType == other.runtimeType &&
          originalText == other.originalText &&
          intermediateTranslation == other.intermediateTranslation &&
          finalTranslation == other.finalTranslation;

  @override
  int get hashCode =>
      originalText.hashCode ^
      intermediateTranslation.hashCode ^
      finalTranslation.hashCode;

  @override
  String toString() {
    return 'BackTranslationResult(original: ${originalText.substring(0, 30)}..., '
        'intermediate: ${intermediateTranslation.translatedText.substring(0, 30)}..., '
        'final: ${backTranslatedText.substring(0, 30)}..., '
        'similarity: ${(similarityScore * 100).toStringAsFixed(1)}%)';
  }
}

/// Represents API configuration with meaningful naming
class ApiConfiguration {
  final bool useOfficialApi;
  final String? apiKey;
  final int maxRetries;
  final Duration timeout;

  ApiConfiguration({
    required this.useOfficialApi,
    this.apiKey,
    this.maxRetries = 4,
    this.timeout = const Duration(seconds: 30),
  });

  /// Validate the configuration
  bool get isValid {
    if (useOfficialApi) {
      return apiKey != null && apiKey!.isNotEmpty;
    }
    return true;
  }

  /// Create a copy with modified fields
  ApiConfiguration copyWith({
    bool? useOfficialApi,
    String? apiKey,
    int? maxRetries,
    Duration? timeout,
  }) {
    return ApiConfiguration(
      useOfficialApi: useOfficialApi ?? this.useOfficialApi,
      apiKey: apiKey ?? this.apiKey,
      maxRetries: maxRetries ?? this.maxRetries,
      timeout: timeout ?? this.timeout,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiConfiguration &&
          runtimeType == other.runtimeType &&
          useOfficialApi == other.useOfficialApi &&
          apiKey == other.apiKey &&
          maxRetries == other.maxRetries &&
          timeout == other.timeout;

  @override
  int get hashCode =>
      useOfficialApi.hashCode ^
      apiKey.hashCode ^
      maxRetries.hashCode ^
      timeout.hashCode;

  @override
  String toString() {
    return 'ApiConfiguration(useOfficial: $useOfficialApi, hasApiKey: ${apiKey != null}, '
        'maxRetries: $maxRetries, timeout: ${timeout.inSeconds}s)';
  }
}
