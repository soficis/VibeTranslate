/// Clean Code use cases with meaningful naming and Single Responsibility
/// Following Clean Architecture principles
library;

import '../../core/errors/either.dart';
import '../../core/errors/failure.dart';
import '../entities/translation.dart';
import '../repositories/translation_repository.dart';

/// Use case for performing translation
/// Single Responsibility: Handle translation business logic
class TranslateTextUseCase {
  final TranslationRepository _repository;

  const TranslateTextUseCase(this._repository);

  /// Execute translation with proper error handling
  Future<Result<TranslationResult>> execute(
    String text,
    String sourceLanguage,
    String targetLanguage,
    ApiConfiguration config,
  ) async {
    if (text.trim().isEmpty) {
      return Right(
        TranslationResult(
          originalText: text,
          translatedText: '',
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        ),
      );
    }

    final request = TranslationRequest(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );

    return _repository.translateText(request, config);
  }
}

/// Use case for performing backtranslation
/// Single Responsibility: Handle backtranslation business logic
class PerformBackTranslationUseCase {
  final TranslationRepository _repository;

  const PerformBackTranslationUseCase(this._repository);

  /// Execute backtranslation with proper error handling
  Future<Result<BackTranslationResult>> execute(
    String text,
    ApiConfiguration config, {
    String intermediateLanguage = 'ja',
  }) async {
    if (text.trim().isEmpty) {
      return Right(
        BackTranslationResult(
          originalText: text,
          intermediateTranslation: TranslationResult(
            originalText: text,
            translatedText: '',
            sourceLanguage: 'en',
            targetLanguage: intermediateLanguage,
          ),
          finalTranslation: TranslationResult(
            originalText: '',
            translatedText: '',
            sourceLanguage: intermediateLanguage,
            targetLanguage: 'en',
          ),
          timestamp: DateTime.now(),
          totalDuration: Duration.zero,
        ),
      );
    }

    return _repository.performBackTranslation(
      text,
      config,
      intermediateLanguage: intermediateLanguage,
    );
  }
}

/// Use case for loading text from file
/// Single Responsibility: Handle file loading business logic
class LoadTextFromFileUseCase {
  final FileRepository _repository;

  const LoadTextFromFileUseCase(this._repository);

  /// Execute file loading with validation
  Future<Result<String>> execute(String filePath) async {
    if (filePath.isEmpty) {
      return Left(FileFailure.invalidFormat(filePath, 'File path is empty'));
    }

    final extension = filePath.split('.').last.toLowerCase();
    if (!_repository.isFileExtensionSupported('.$extension')) {
      return Left(
        FileFailure.invalidFormat(
          filePath,
          'Unsupported file type. Supported: ${_repository.supportedExtensions.join(", ")}',
        ),
      );
    }

    return _repository.loadTextFromFile(filePath);
  }
}

/// Use case for saving text to file
/// Single Responsibility: Handle file saving business logic
class SaveTextToFileUseCase {
  final FileRepository _repository;

  const SaveTextToFileUseCase(this._repository);

  /// Execute file saving with validation
  Future<Result<void>> execute(String content, String filePath) async {
    if (filePath.isEmpty) {
      return Left(FileFailure.invalidFormat(filePath, 'File path is empty'));
    }

    if (content.isEmpty) {
      return Left(FileFailure.invalidFormat(filePath, 'Content is empty'));
    }

    return _repository.saveTextToFile(content, filePath);
  }
}

/// Use case for copying text to clipboard
/// Single Responsibility: Handle clipboard operations business logic
class CopyTextToClipboardUseCase {
  final ClipboardRepository _repository;

  const CopyTextToClipboardUseCase(this._repository);

  /// Execute clipboard copy with validation
  Future<Result<void>> execute(String text) async {
    if (text.trim().isEmpty) {
      return Left(AppFailure(message: 'No text to copy'));
    }

    return _repository.copyTextToClipboard(text);
  }
}

/// Use case for getting text from clipboard
/// Single Responsibility: Handle clipboard retrieval business logic
class GetTextFromClipboardUseCase {
  final ClipboardRepository _repository;

  const GetTextFromClipboardUseCase(this._repository);

  /// Execute clipboard retrieval
  Future<Result<String?>> execute() async {
    return _repository.getTextFromClipboard();
  }
}
