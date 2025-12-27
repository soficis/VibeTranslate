library;

import '../../core/utils/bleu_scorer.dart';

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
  final TranslationQualityAssessment? qualityAssessment;

  BackTranslationResult({
    required this.originalText,
    required this.intermediateTranslation,
    required this.finalTranslation,
    required this.timestamp,
    required this.totalDuration,
    this.qualityAssessment,
  });

  /// Get the final backtranslated text
  String get backTranslatedText => finalTranslation.translatedText;

  /// Get BLEU score (returns 0.0 if no assessment available)
  double get bleuScore => qualityAssessment?.bleuScore ?? 0.0;

  /// Get confidence level
  String get confidenceLevel => qualityAssessment?.confidenceLevel ?? 'Unknown';

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
    final bleuInfo = qualityAssessment != null
        ? 'BLEU: ${qualityAssessment!.bleuPercentage} (${qualityAssessment!.confidenceLevel})'
        : 'BLEU: Not calculated';
    return 'BackTranslationResult(original: ${originalText.substring(0, 30)}..., '
        'intermediate: ${intermediateTranslation.translatedText.substring(0, 30)}..., '
        'final: ${backTranslatedText.substring(0, 30)}..., '
        '$bleuInfo)';
  }
}

enum TranslationProviderId {
  local,
  googleUnofficial,
  googleOfficial,
}

extension TranslationProviderIdX on TranslationProviderId {
  String get storageValue {
    switch (this) {
      case TranslationProviderId.local:
        return 'local';
      case TranslationProviderId.googleUnofficial:
        return 'google_unofficial';
      case TranslationProviderId.googleOfficial:
        return 'google_official';
    }
  }

  String get displayName {
    switch (this) {
      case TranslationProviderId.local:
        return 'Local (Offline)';
      case TranslationProviderId.googleUnofficial:
        return 'Google Translate (Unofficial / Free)';
      case TranslationProviderId.googleOfficial:
        return 'Google Cloud Translate (Official)';
    }
  }

  bool get isOfficial => this == TranslationProviderId.googleOfficial;

  static TranslationProviderId fromStorage(String? value) {
    switch (value) {
      case 'local':
        return TranslationProviderId.local;
      case 'google_official':
        return TranslationProviderId.googleOfficial;
      case 'google_unofficial':
      default:
        return TranslationProviderId.googleUnofficial;
    }
  }
}

/// Represents API configuration with meaningful naming
class ApiConfiguration {
  final TranslationProviderId providerId;
  final String? apiKey;
  final int maxRetries;
  final Duration timeout;
  final String? localServiceUrl;
  final String? localModelDir;
  final bool localAutoStart;

  ApiConfiguration({
    required this.providerId,
    this.apiKey,
    this.maxRetries = 4,
    this.timeout = const Duration(seconds: 30),
    this.localServiceUrl,
    this.localModelDir,
    this.localAutoStart = true,
  });

  /// Validate the configuration
  bool get isValid {
    if (useOfficialApi) {
      return apiKey != null && apiKey!.isNotEmpty;
    }
    return true;
  }

  bool get useOfficialApi => providerId.isOfficial;

  bool get isLocal => providerId == TranslationProviderId.local;

  /// Create a copy with modified fields
  ApiConfiguration copyWith({
    TranslationProviderId? providerId,
    String? apiKey,
    int? maxRetries,
    Duration? timeout,
    String? localServiceUrl,
    String? localModelDir,
    bool? localAutoStart,
  }) {
    return ApiConfiguration(
      providerId: providerId ?? this.providerId,
      apiKey: apiKey ?? this.apiKey,
      maxRetries: maxRetries ?? this.maxRetries,
      timeout: timeout ?? this.timeout,
      localServiceUrl: localServiceUrl ?? this.localServiceUrl,
      localModelDir: localModelDir ?? this.localModelDir,
      localAutoStart: localAutoStart ?? this.localAutoStart,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiConfiguration &&
          runtimeType == other.runtimeType &&
          providerId == other.providerId &&
          apiKey == other.apiKey &&
          maxRetries == other.maxRetries &&
          timeout == other.timeout &&
          localServiceUrl == other.localServiceUrl &&
          localModelDir == other.localModelDir &&
          localAutoStart == other.localAutoStart;

  @override
  int get hashCode =>
      providerId.hashCode ^
      apiKey.hashCode ^
      maxRetries.hashCode ^
      timeout.hashCode ^
      localServiceUrl.hashCode ^
      localModelDir.hashCode ^
      localAutoStart.hashCode;

  @override
  String toString() {
    return 'ApiConfiguration(providerId: ${providerId.storageValue}, hasApiKey: ${apiKey != null}, '
        'maxRetries: $maxRetries, timeout: ${timeout.inSeconds}s, localServiceUrl: ${localServiceUrl ?? "default"})';
  }
}
