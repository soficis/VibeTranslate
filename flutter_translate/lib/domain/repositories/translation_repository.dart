/// Clean Code repository interfaces with meaningful naming
/// Following Dependency Inversion principle and Single Responsibility
library;

import '../entities/translation.dart';
import '../../core/errors/either.dart';

/// Repository interface for translation operations
/// Single Responsibility: Define translation data access contract
abstract class TranslationRepository {
  /// Translate text from source language to target language
  Future<Result<TranslationResult>> translateText(
    TranslationRequest request,
    ApiConfiguration config,
  );

  /// Perform backtranslation (source -> intermediate -> source)
  Future<Result<BackTranslationResult>> performBackTranslation(
    String text,
    ApiConfiguration config, {
    String intermediateLanguage = 'ja',
  });

  /// Check if the repository is properly configured
  bool get isConfigured;

  /// Get the name of this translation service
  String get serviceName;
}

/// Repository interface for file operations
/// Single Responsibility: Define file data access contract
abstract class FileRepository {
  /// Load text content from a file
  Future<Result<String>> loadTextFromFile(String filePath);

  /// Save text content to a file
  Future<Result<void>> saveTextToFile(String content, String filePath);

  /// Get supported file extensions
  List<String> get supportedExtensions;

  /// Extract text from HTML content
  Result<String> extractTextFromHtml(String htmlContent);

  /// Check if file extension is supported
  bool isFileExtensionSupported(String extension);
}

/// Repository interface for application preferences
/// Single Responsibility: Define preferences data access contract
abstract class PreferencesRepository {
  /// Get boolean preference value
  Future<Result<bool>> getBoolPreference(String key,
      {bool defaultValue = false});

  /// Set boolean preference value
  Future<Result<void>> setBoolPreference(String key, bool value);

  /// Get string preference value
  Future<Result<String?>> getStringPreference(String key);

  /// Set string preference value
  Future<Result<void>> setStringPreference(String key, String value);

  /// Remove preference value
  Future<Result<void>> removePreference(String key);

  /// Clear all preferences
  Future<Result<void>> clearAllPreferences();
}

/// Repository interface for clipboard operations
/// Single Responsibility: Define clipboard data access contract
abstract class ClipboardRepository {
  /// Copy text to clipboard
  Future<Result<void>> copyTextToClipboard(String text);

  /// Get text from clipboard
  Future<Result<String?>> getTextFromClipboard();
}
