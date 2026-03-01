library;

import 'dart:math';
import '../../core/constants/app_constants.dart';
import '../../core/errors/either.dart';
import '../../core/errors/failure.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/translation.dart';

/// Service for handling retry logic with exponential backoff
class RetryService {
  final Logger logger = Logger.instance;
  final Random _random = Random();

  /// Execute a translation operation with retry logic
  Future<Result<T>> executeWithRetry<T>(
    Future<Result<T>> Function() operation,
    ApiConfiguration config, {
    required String operationName,
    required void Function(String) statusCallback,
  }) async {
    final maxAttempts = config.maxRetries < 1 ? 1 : config.maxRetries;

    return _executeWithRetryLoop(
      operation,
      maxAttempts,
      maxAttempts,
      operationName,
      statusCallback,
    );
  }

  /// Internal retry loop implementation
  Future<Result<T>> _executeWithRetryLoop<T>(
    Future<Result<T>> Function() operation,
    int remainingAttempts,
    int maxAttempts,
    String operationName,
    void Function(String) statusCallback,
  ) async {
    final attemptNumber = maxAttempts - remainingAttempts + 1;

    try {
      final result = await operation();

      if (result.isRight || remainingAttempts <= 1) {
        return result;
      }

      // If we get here, it means the operation failed and we have retries left
      final resultLeft = result.left;
      logger.error(
        '$operationName attempt $attemptNumber failed: ${resultLeft.message}',
      );

      final delay = _calculateDelay(attemptNumber);
      final delaySeconds = delay.inMilliseconds / 1000.0;

      statusCallback(
        'Error. Retrying in ${delaySeconds.toStringAsFixed(1)}s '
        '(attempt $attemptNumber/$maxAttempts)',
      );

      await Future.delayed(delay);

      return _executeWithRetryLoop(
        operation,
        remainingAttempts - 1,
        maxAttempts,
        operationName,
        statusCallback,
      );
    } catch (e) {
      logger.error('$operationName attempt $attemptNumber error: $e');

      if (remainingAttempts <= 1) {
        return Left(NetworkFailure(
          message: '$operationName failed after all retries: $e',
        ),);
      }

      final delay = _calculateDelay(attemptNumber);
      final delaySeconds = delay.inMilliseconds / 1000.0;

      statusCallback(
        'Error. Retrying in ${delaySeconds.toStringAsFixed(1)}s '
        '(attempt $attemptNumber/$maxAttempts)',
      );

      await Future.delayed(delay);

      return _executeWithRetryLoop(
        operation,
        remainingAttempts - 1,
        maxAttempts,
        operationName,
        statusCallback,
      );
    }
  }

  /// Calculate delay with exponential backoff and jitter
  Duration _calculateDelay(int attemptNumber) {
    final baseDelayMs = AppConstants.baseRetryDelayMs.toDouble();
    final multiplier =
        pow(AppConstants.retryBackoffMultiplier, attemptNumber - 1);
    final exponentialDelay = baseDelayMs * multiplier;

    final jitter = _random.nextInt(AppConstants.maxRetryJitterMs * 2) -
        AppConstants.maxRetryJitterMs;
    final totalDelayMs = exponentialDelay + jitter;

    return Duration(milliseconds: max(100, totalDelayMs.toInt()));
  }

  /// Execute backtranslation with proper retry handling for both steps
  Future<Result<BackTranslationResult>> executeBackTranslationWithRetry(
    Future<Result<TranslationResult>> Function() firstTranslation,
    Future<Result<TranslationResult>> Function(String) secondTranslation,
    String originalText,
    ApiConfiguration config, {
    required String intermediateLanguage,
    required void Function(String) statusCallback,
  }) async {
    final startTime = DateTime.now();

    // First translation: source -> intermediate
    statusCallback('Translating to $intermediateLanguage...');

    final firstResult = await executeWithRetry(
      firstTranslation,
      config,
      operationName: 'First translation',
      statusCallback: statusCallback,
    );

    if (firstResult.isLeft) {
      return Left(firstResult.left);
    }

    final intermediateResult = firstResult.right;

    // Second translation: intermediate -> source
    statusCallback('Translating back to English...');

    final secondResult = await executeWithRetry(
      () => secondTranslation(intermediateResult.translatedText),
      config,
      operationName: 'Second translation',
      statusCallback: statusCallback,
    );

    if (secondResult.isLeft) {
      return Left(secondResult.left);
    }

    final finalResult = secondResult.right;
    final totalDuration = DateTime.now().difference(startTime);

    final backTranslationResult = BackTranslationResult(
      originalText: originalText,
      intermediateTranslation: intermediateResult,
      finalTranslation: finalResult,
      timestamp: startTime,
      totalDuration: totalDuration,
    );

    logger.info(
      'Backtranslation completed successfully: '
      '${originalText.length} -> ${intermediateResult.translatedText.length} -> ${finalResult.translatedText.length} chars '
      'in ${totalDuration.inSeconds}s',
    );

    return Right(backTranslationResult);
  }
}
