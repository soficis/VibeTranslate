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
    final preview = text.substring(0, text.length > 50 ? 50 : text.length);
    return 'TranslationRequest(text: $preview..., '
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
    final originalPreview = originalText.substring(
      0,
      originalText.length > 30 ? 30 : originalText.length,
    );
    final translatedPreview = translatedText.substring(
      0,
      translatedText.length > 30 ? 30 : translatedText.length,
    );
    return 'TranslationResult(original: $originalPreview..., '
        'translated: $translatedPreview..., '
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
    final originalPreview = originalText.substring(
      0,
      originalText.length > 30 ? 30 : originalText.length,
    );
    final intermediatePreview =
        intermediateTranslation.translatedText.substring(
      0,
      intermediateTranslation.translatedText.length > 30
          ? 30
          : intermediateTranslation.translatedText.length,
    );
    final backPreview = backTranslatedText.substring(
      0,
      backTranslatedText.length > 30 ? 30 : backTranslatedText.length,
    );

    return 'BackTranslationResult(original: $originalPreview..., '
        'intermediate: $intermediatePreview..., '
        'final: $backPreview..., '
        'duration: ${totalDuration.inMilliseconds}ms)';
  }
}

enum TranslationProviderId {
  googleUnofficial,
}

extension TranslationProviderIdX on TranslationProviderId {
  String get storageValue => 'google_unofficial';

  String get displayName => 'Google Translate (Unofficial / Free)';

  static TranslationProviderId fromStorage(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'google_unofficial':
      case 'unofficial':
      case 'google_unofficial_free':
      case 'google_free':
      case 'googletranslate':
      default:
        return TranslationProviderId.googleUnofficial;
    }
  }
}

/// Represents API configuration with meaningful naming
class ApiConfiguration {
  final TranslationProviderId providerId;
  final int maxRetries;
  final Duration timeout;

  ApiConfiguration({
    required this.providerId,
    this.maxRetries = 4,
    this.timeout = const Duration(seconds: 30),
  });

  /// Validate the configuration
  bool get isValid => true;

  /// Create a copy with modified fields
  ApiConfiguration copyWith({
    TranslationProviderId? providerId,
    int? maxRetries,
    Duration? timeout,
  }) {
    return ApiConfiguration(
      providerId: providerId ?? this.providerId,
      maxRetries: maxRetries ?? this.maxRetries,
      timeout: timeout ?? this.timeout,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiConfiguration &&
          runtimeType == other.runtimeType &&
          providerId == other.providerId &&
          maxRetries == other.maxRetries &&
          timeout == other.timeout;

  @override
  int get hashCode =>
      providerId.hashCode ^ maxRetries.hashCode ^ timeout.hashCode;

  @override
  String toString() {
    return 'ApiConfiguration(providerId: ${providerId.storageValue}, '
        'maxRetries: $maxRetries, timeout: ${timeout.inSeconds}s)';
  }
}
