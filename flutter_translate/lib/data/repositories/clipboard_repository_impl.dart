/// Clean Code clipboard repository implementation
/// Following Single Responsibility and meaningful naming
library;

import 'package:flutter/services.dart';
import '../../core/errors/either.dart';
import '../../core/errors/failure.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/translation_repository.dart';

/// Implementation of ClipboardRepository interface
/// Single Responsibility: Handle clipboard operations safely
class ClipboardRepositoryImpl implements ClipboardRepository {
  final Logger logger = Logger.instance;

  @override
  Future<Result<void>> copyTextToClipboard(String text) async {
    try {
      if (text.isEmpty) {
        logger.warning('Attempted to copy empty text to clipboard');
        return const Right(null);
      }

      await Clipboard.setData(ClipboardData(text: text));
      logger
          .info('Successfully copied text to clipboard (${text.length} chars)');
      return const Right(null);
    } catch (e) {
      final errorMessage = 'Failed to copy text to clipboard: $e';
      logger.error(errorMessage);
      return Left(AppFailure(message: errorMessage));
    }
  }

  @override
  Future<Result<String?>> getTextFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text;

      if (text != null && text.isNotEmpty) {
        logger.info(
            'Successfully retrieved text from clipboard (${text.length} chars)');
      } else {
        logger.debug('Clipboard is empty or contains no text');
      }

      return Right(text);
    } catch (e) {
      final errorMessage = 'Failed to get text from clipboard: $e';
      logger.error(errorMessage);
      return Left(AppFailure(message: errorMessage));
    }
  }
}

/// Factory for creating ClipboardRepository instances
class ClipboardRepositoryFactory {
  static ClipboardRepository create() {
    return ClipboardRepositoryImpl();
  }
}
