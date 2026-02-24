library;

import 'package:http/http.dart' as http;
import '../../core/errors/either.dart';
import '../../core/errors/failure.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/translation.dart';
import '../../domain/repositories/translation_repository.dart';
import '../services/retry_service.dart';
import '../services/translation_service.dart';

/// Implementation of TranslationRepository interface
/// Single Responsibility: Coordinate translation operations with services
class TranslationRepositoryImpl implements TranslationRepository {
  final UnofficialGoogleTranslateService _unofficialService;
  final RetryService _retryService;
  final Logger logger = Logger.instance;

  TranslationRepositoryImpl(http.Client httpClient)
      : _unofficialService = UnofficialGoogleTranslateService(httpClient),
        _retryService = RetryService();

  @override
  String get serviceName => 'Translation Repository';

  @override
  bool get isConfigured => true;

  @override
  Future<Result<TranslationResult>> translateText(
    TranslationRequest request,
    ApiConfiguration config,
  ) async {
    return _retryService.executeWithRetry(
      () => _translateWithService(request, config),
      config,
      operationName: 'Translation',
      statusCallback: (message) {}, // No callback needed for single translation
    );
  }

  /// Internal method to run translation service
  Future<Result<TranslationResult>> _translateWithService(
    TranslationRequest request,
    ApiConfiguration config,
  ) async {
    logger.info('Starting translation with config: $config');
    logger.info('Using service: ${_unofficialService.serviceName}');

    final result = await _unofficialService.translate(request, config);

    logger.info('Service result: ${result.isRight ? "Success" : "Failure"}');
    if (result.isLeft) {
      logger.error('Service failure: ${result.left.message}');
    }

    return result;
  }

  @override
  Future<Result<BackTranslationResult>> performBackTranslation(
    String text,
    ApiConfiguration config, {
    String intermediateLanguage = 'ja',
  }) async {
    logger.info('Repository: performBackTranslation called');
    logger.info('Repository: text: "$text"');
    logger.info('Repository: config: $config');
    logger.info('Repository: intermediateLanguage: $intermediateLanguage');

    if (text.trim().isEmpty) {
      logger.info('Repository: text is empty, returning empty result');
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

    // First translation: source -> intermediate
    final firstRequest = TranslationRequest(
      text: text,
      sourceLanguage: 'en',
      targetLanguage: intermediateLanguage,
    );

    Future<Result<TranslationResult>> firstTranslation() =>
        _translateWithService(firstRequest, config);

    // Second translation: intermediate -> source
    Future<Result<TranslationResult>> secondTranslation(
      String intermediateText,
    ) async {
      final secondRequest = TranslationRequest(
        text: intermediateText,
        sourceLanguage: intermediateLanguage,
        targetLanguage: 'en',
      );
      return _translateWithService(secondRequest, config);
    }

    logger.info('Repository: calling retry service');
    final result = await _retryService.executeBackTranslationWithRetry(
      firstTranslation,
      secondTranslation,
      text,
      config,
      intermediateLanguage: intermediateLanguage,
      statusCallback: (message) {
        logger.info('Repository: status callback: $message');
      },
    );
    logger.info(
      'Repository: retry service result: ${result.isRight ? "Success" : "Failure"}',
    );
    return result;
  }

  @override
  Future<Result<String>> detectLanguage(
    String text,
    ApiConfiguration config,
  ) async {
    logger.debug('Detect language provider: ${config.providerId}');
    if (text.trim().isEmpty) {
      return Left(AppFailure(message: 'Text is empty'));
    }
    return const Right('en');
  }
}

/// Factory for creating TranslationRepository instances
class TranslationRepositoryFactory {
  static TranslationRepository create() {
    final httpClient = http.Client();
    return TranslationRepositoryImpl(httpClient);
  }

  /// Create with custom HTTP client (useful for testing)
  static TranslationRepository createWithClient(http.Client client) {
    return TranslationRepositoryImpl(client);
  }
}
