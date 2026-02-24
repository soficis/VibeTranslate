library;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/errors/failure.dart';
import '../../core/utils/logger.dart';
import '../../data/repositories/clipboard_repository_impl.dart';
import '../../data/repositories/file_repository_impl.dart';
import '../../data/repositories/preferences_repository_impl.dart';
import '../../data/repositories/translation_repository_impl.dart';
import '../../domain/entities/output_format.dart';
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
  late final PerformBackTranslationUseCase _performBackTranslationUseCase;
  late final LoadTextFromFileUseCase _loadTextFromFileUseCase;
  late final SaveTextToFileUseCase _saveTextToFileUseCase;
  late final CopyTextToClipboardUseCase _copyTextToClipboardUseCase;

  // State
  String _inputText = '';
  String _intermediateText = '';
  String _finalText = '';
  String _statusMessage = 'Ready';
  bool _isLoading = false;
  bool _isDarkTheme = false;
  TranslationProviderId _providerId = TranslationProviderId.googleUnofficial;
  OutputFormat _outputFormat = OutputFormat.html;

  // Language state
  String _sourceLanguage = 'en';
  String _targetLanguage = 'ja';

  // Getters
  String get inputText => _inputText;
  String get intermediateText => _intermediateText;
  String get finalText => _finalText;
  String get statusMessage => _statusMessage;
  bool get isLoading => _isLoading;
  bool get isDarkTheme => _isDarkTheme;
  TranslationProviderId get providerId => _providerId;
  OutputFormat get outputFormat => _outputFormat;

  String get sourceLanguage => _sourceLanguage;
  String get targetLanguage => _targetLanguage;

  List<String> get availableLanguages => ['en', 'ja', 'fr', 'de', 'es'];

  // Configuration
  ApiConfiguration get apiConfiguration => ApiConfiguration(
        providerId: _providerId,
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

    _performBackTranslationUseCase =
        PerformBackTranslationUseCase(_translationRepository);
    _loadTextFromFileUseCase = LoadTextFromFileUseCase(_fileRepository);
    _saveTextToFileUseCase = SaveTextToFileUseCase(_fileRepository);
    _copyTextToClipboardUseCase =
        CopyTextToClipboardUseCase(_clipboardRepository);
  }

  /// Load user preferences
  Future<void> loadPreferences() async {
    try {
      final themeResult = await _preferencesRepository.getThemePreference();
      final providerIdResult =
          await _preferencesRepository.getProviderIdPreference();

      themeResult.fold(
        (failure) => Logger.instance
            .error('Failed to load theme preference: ${failure.message}'),
        (isDark) => _isDarkTheme = isDark,
      );

      providerIdResult.fold(
        (failure) => Logger.instance
            .error('Failed to load provider preference: ${failure.message}'),
        (providerValue) =>
            _providerId = TranslationProviderIdX.fromStorage(providerValue),
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
  Future<void> updateApiConfiguration(
    TranslationProviderId providerId,
  ) async {
    _providerId = providerId;
    notifyListeners();

    final providerResult = await _preferencesRepository.setProviderIdPreference(
      providerId.storageValue,
    );

    providerResult.fold(
      (failure) => Logger.instance
          .error('Failed to save provider preference: ${failure.message}'),
      (_) => Logger.instance
          .debug('Provider preference saved: ${providerId.storageValue}'),
    );
  }

  /// Perform backtranslation
  Future<void> performBackTranslation() async {
    Logger.instance.info('Starting performBackTranslation');
    Logger.instance.info('Input text: "$_inputText"');
    Logger.instance.info(
        'Source language: $_sourceLanguage, Target language: $_targetLanguage',);
    Logger.instance.info(
      'API config: provider=${_providerId.storageValue}',
    );

    if (_inputText.trim().isEmpty) {
      _updateStatus('Please enter text to translate');
      return;
    }

    if (_sourceLanguage.length != 2 || _targetLanguage.length != 2) {
      _updateStatus('Invalid language codes');
      return;
    }

    _setLoading(true);
    _clearResults();
    _updateStatus('Starting translation...');

    try {
      final result = await _performBackTranslationUseCase.execute(
        _inputText,
        apiConfiguration,
        sourceLanguage: _sourceLanguage,
        targetLanguage: _targetLanguage,
      );

      Logger.instance.info(
          'Translation result: ${result.isRight ? "Success" : "Failure"}',);
      if (result.isLeft) {
        Logger.instance.error('Translation failure: $result.left.message');
      }

      result.fold(
        _handleTranslationError,
        _handleTranslationSuccess,
      );
    } catch (e) {
      Logger.instance.error('Unexpected error in performBackTranslation: $e');
      _handleTranslationError(AppFailure(message: 'Unexpected error: $e'));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> detectLanguage() async {
    if (_inputText.trim().isEmpty) {
      _updateStatus('Please enter text to detect');
      return;
    }

    _setLoading(true);

    try {
      final result = await _performBackTranslationUseCase.detectLanguage(
        _inputText,
        apiConfiguration,
      );

      result.fold(
        _handleTranslationError,
        (detected) {
          _sourceLanguage = detected;
          notifyListeners();
          _updateStatus('Detected language: $detected');
        },
      );
    } catch (e) {
      _handleTranslationError(AppFailure(message: 'Detection error: $e'));
    } finally {
      _setLoading(false);
    }
  }

  void updateSourceLanguage(String language) {
    _sourceLanguage = language;
    notifyListeners();
  }

  void updateTargetLanguage(String language) {
    _targetLanguage = language;
    notifyListeners();
  }

  /// Update output format
  void updateOutputFormat(OutputFormat format) {
    _outputFormat = format;
    notifyListeners();
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
            'File loaded successfully (${content.length} characters)',
          );
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
    Logger.instance.info(
        'Translation success: intermediate=$_intermediateText, final=$_finalText',);
    notifyListeners();
  }

  /// Handle translation error
  void _handleTranslationError(Failure failure) {
    _updateStatus('Translation failed: ${failure.message}');
    Logger.instance.error('Translation error: $failure.message');
    Logger.instance.error('Error type: ${failure.runtimeType}');
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
