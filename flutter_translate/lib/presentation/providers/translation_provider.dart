/// Clean Code provider with Single Responsibility
/// Following State Management principles and meaningful naming
library;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/errors/either.dart';
import '../../core/errors/failure.dart';
import '../../core/utils/logger.dart';
import '../../data/repositories/clipboard_repository_impl.dart';
import '../../data/repositories/file_repository_impl.dart';
import '../../data/repositories/preferences_repository_impl.dart';
import '../../data/repositories/translation_repository_impl.dart';
import '../../domain/entities/translation.dart';
import '../../domain/usecases/translation_usecases.dart';

/// Provider for managing translation application state
/// Single Responsibility: Handle application state and business logic
class TranslationProvider extends ChangeNotifier {
  // Repositories
  late final TranslationRepositoryImpl _translationRepository;
  late final FileRepositoryImpl _fileRepository;
  late final PreferencesRepositoryImpl _preferencesRepository;
  late final ClipboardRepositoryImpl _clipboardRepository;

  // Use cases
  late final TranslateTextUseCase _translateTextUseCase;
  late final PerformBackTranslationUseCase _performBackTranslationUseCase;
  late final LoadTextFromFileUseCase _loadTextFromFileUseCase;
  late final SaveTextToFileUseCase _saveTextToFileUseCase;
  late final CopyTextToClipboardUseCase _copyTextToClipboardUseCase;
  late final GetTextFromClipboardUseCase _getTextFromClipboardUseCase;

  // State
  String _inputText = '';
  String _intermediateText = '';
  String _finalText = '';
  String _statusMessage = 'Ready';
  bool _isLoading = false;
  bool _isDarkTheme = false;
  bool _useOfficialApi = false;
  String _apiKey = '';

  // Getters
  String get inputText => _inputText;
  String get intermediateText => _intermediateText;
  String get finalText => _finalText;
  String get statusMessage => _statusMessage;
  bool get isLoading => _isLoading;
  bool get isDarkTheme => _isDarkTheme;
  bool get useOfficialApi => _useOfficialApi;
  String get apiKey => _apiKey;

  // Configuration
  ApiConfiguration get apiConfiguration => ApiConfiguration(
        useOfficialApi: _useOfficialApi,
        apiKey: _apiKey.isNotEmpty ? _apiKey : null,
      );

  TranslationProvider() {
    _initializeDependencies();
  }

  /// Initialize all dependencies
  void _initializeDependencies() {
    _translationRepository = TranslationRepositoryImpl(http.Client());
    _fileRepository = FileRepositoryImpl();
    _preferencesRepository = PreferencesRepositoryImpl();
    _clipboardRepository = ClipboardRepositoryImpl();

    _translateTextUseCase = TranslateTextUseCase(_translationRepository);
    _performBackTranslationUseCase =
        PerformBackTranslationUseCase(_translationRepository);
    _loadTextFromFileUseCase = LoadTextFromFileUseCase(_fileRepository);
    _saveTextToFileUseCase = SaveTextToFileUseCase(_fileRepository);
    _copyTextToClipboardUseCase =
        CopyTextToClipboardUseCase(_clipboardRepository);
    _getTextFromClipboardUseCase =
        GetTextFromClipboardUseCase(_clipboardRepository);
  }

  /// Load user preferences
  Future<void> loadPreferences() async {
    try {
      final themeResult = await _preferencesRepository.getThemePreference();
      final apiKeyResult = await _preferencesRepository.getApiKeyPreference();
      final useOfficialResult =
          await _preferencesRepository.getUseOfficialApiPreference();

      themeResult.fold(
        (failure) => Logger.instance
            .error('Failed to load theme preference: ${failure.message}'),
        (isDark) => _isDarkTheme = isDark,
      );

      apiKeyResult.fold(
        (failure) =>
            Logger.instance.error('Failed to load API key: ${failure.message}'),
        (key) => _apiKey = key ?? '',
      );

      useOfficialResult.fold(
        (failure) => Logger.instance
            .error('Failed to load API preference: ${failure.message}'),
        (useOfficial) => _useOfficialApi = useOfficial,
      );

      notifyListeners();
    } catch (e) {
      Logger.instance.error('Failed to load preferences: $e');
    }
  }

  /// Update input text
  void updateInputText(String text) {
    _inputText = text;
    notifyListeners();
  }

  /// Update theme preference
  Future<void> updateTheme(bool isDark) async {
    _isDarkTheme = isDark;
    notifyListeners();

    final result = await _preferencesRepository.setThemePreference(isDark);
    result.fold(
      (failure) => Logger.instance
          .error('Failed to save theme preference: ${failure.message}'),
      (_) => Logger.instance.debug('Theme preference saved: $isDark'),
    );
  }

  /// Update API configuration
  Future<void> updateApiConfiguration(bool useOfficial, String apiKey) async {
    _useOfficialApi = useOfficial;
    _apiKey = apiKey;
    notifyListeners();

    final apiKeyResult =
        await _preferencesRepository.setApiKeyPreference(apiKey);
    final useOfficialResult =
        await _preferencesRepository.setUseOfficialApiPreference(useOfficial);

    apiKeyResult.fold(
      (failure) =>
          Logger.instance.error('Failed to save API key: ${failure.message}'),
      (_) => Logger.instance.debug('API key saved'),
    );

    useOfficialResult.fold(
      (failure) => Logger.instance
          .error('Failed to save API preference: ${failure.message}'),
      (_) => Logger.instance.debug('API preference saved: $useOfficial'),
    );
  }

  /// Perform backtranslation
  Future<void> performBackTranslation() async {
    if (_inputText.trim().isEmpty) {
      _updateStatus('Please enter text to translate');
      return;
    }

    _setLoading(true);
    _clearResults();

    try {
      final result = await _performBackTranslationUseCase.execute(
        _inputText,
        apiConfiguration,
      );

      result.fold(
        _handleTranslationError,
        _handleTranslationSuccess,
      );
    } catch (e) {
      _handleTranslationError(AppFailure(message: 'Unexpected error: $e'));
    } finally {
      _setLoading(false);
    }
  }

  /// Load text from file
  Future<void> loadTextFromFile(String filePath) async {
    _setLoading(true);

    try {
      final result = await _loadTextFromFileUseCase.execute(filePath);

      result.fold(
        (failure) => _updateStatus('Failed to load file: ${failure.message}'),
        (content) {
          _inputText = content;
          _updateStatus(
              'File loaded successfully (${content.length} characters)');
          notifyListeners();
        },
      );
    } catch (e) {
      _updateStatus('Unexpected error loading file: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Save final text to file
  Future<void> saveTextToFile(String filePath) async {
    if (_finalText.isEmpty) {
      _updateStatus('No text to save');
      return;
    }

    _setLoading(true);

    try {
      final result = await _saveTextToFileUseCase.execute(_finalText, filePath);

      result.fold(
        (failure) => _updateStatus('Failed to save file: ${failure.message}'),
        (_) => _updateStatus('File saved successfully'),
      );
    } catch (e) {
      _updateStatus('Unexpected error saving file: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Copy final text to clipboard
  Future<void> copyTextToClipboard() async {
    if (_finalText.isEmpty) {
      _updateStatus('No text to copy');
      return;
    }

    try {
      final result = await _copyTextToClipboardUseCase.execute(_finalText);

      result.fold(
        (failure) =>
            _updateStatus('Failed to copy to clipboard: ${failure.message}'),
        (_) => _updateStatus('Text copied to clipboard'),
      );
    } catch (e) {
      _updateStatus('Unexpected error copying to clipboard: $e');
    }
  }

  /// Handle successful translation
  void _handleTranslationSuccess(BackTranslationResult result) {
    _intermediateText = result.intermediateTranslation.translatedText;
    _finalText = result.finalTranslation.translatedText;
    _updateStatus('Backtranslation completed successfully');
    notifyListeners();
  }

  /// Handle translation error
  void _handleTranslationError(Failure failure) {
    _updateStatus('Translation failed: ${failure.message}');
    Logger.instance.error('Translation error: ${failure.message}');
  }

  /// Update status message
  void _updateStatus(String message) {
    _statusMessage = message;
    Logger.instance.info('Status: $message');
    notifyListeners();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Clear translation results
  void _clearResults() {
    _intermediateText = '';
    _finalText = '';
    notifyListeners();
  }
}
