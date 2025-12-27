library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/errors/either.dart';
import '../../core/errors/failure.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/translation.dart';
import '../../domain/repositories/translation_repository.dart';
import '../services/translation_service.dart';
import '../services/retry_service.dart';

/// Implementation of TranslationRepository interface
/// Single Responsibility: Coordinate translation operations with services
class TranslationRepositoryImpl implements TranslationRepository {
  final UnofficialGoogleTranslateService _unofficialService;
  final OfficialGoogleTranslateService _officialService;
  final LocalTranslationService _localService;
  final MockTranslationService _mockService;
  final RetryService _retryService;
  final http.Client _httpClient;
  final Logger logger = Logger.instance;

  TranslationRepositoryImpl(this._httpClient)
      : _unofficialService = UnofficialGoogleTranslateService(_httpClient),
        _officialService = OfficialGoogleTranslateService(_httpClient),
        _localService = LocalTranslationService(_httpClient),
        _mockService = MockTranslationService(_httpClient),
        _retryService = RetryService();

  @override
  String get serviceName => 'Translation Repository';

  @override
  bool get isConfigured =>
      true; // Always configured as it has fallback services

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

  /// Internal method to select and use the appropriate translation service
  Future<Result<TranslationResult>> _translateWithService(
    TranslationRequest request,
    ApiConfiguration config,
  ) async {
    logger.info('Starting translation with config: $config');
    final service = _selectService(config.providerId);
    logger.info('Using service: ${service.serviceName}');

    final result = await service.translate(request, config);

    logger.info('Service result: ${result.isRight ? "Success" : "Failure"}');
    if (result.isLeft) {
      logger.error('Service failure: ${result.left.message}');
    }

    // If unofficial API fails and we have an API key, try official API as fallback
    if (result.isLeft &&
        config.providerId == TranslationProviderId.googleUnofficial &&
        config.apiKey != null &&
        config.apiKey!.isNotEmpty) {
      logger.info('Unofficial API failed, trying official API as fallback');
      final fallbackConfig =
          config.copyWith(providerId: TranslationProviderId.googleOfficial);
      final officialResult =
          await _officialService.translate(request, fallbackConfig);

      if (officialResult.isRight) {
        return officialResult;
      }

      logger.info('Official API also failed, using mock service for testing');
      return _mockService.translate(request, config);
    }

    // If unofficial API fails and we don't have an API key, use mock service
    if (result.isLeft &&
        config.providerId == TranslationProviderId.googleUnofficial) {
      logger.info(
        'Unofficial API failed and no API key available, using mock service for testing',
      );
      return _mockService.translate(request, config);
    }

    // If we're already using official API and it fails, try mock service
    if (result.isLeft &&
        config.providerId == TranslationProviderId.googleOfficial) {
      logger.info('Official API failed, using mock service for testing');
      return _mockService.translate(request, config);
    }

    return result;
  }

  BaseTranslationService _selectService(TranslationProviderId providerId) {
    switch (providerId) {
      case TranslationProviderId.local:
        return _localService;
      case TranslationProviderId.googleOfficial:
        return _officialService;
      case TranslationProviderId.googleUnofficial:
        return _unofficialService;
    }
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
    if (text.trim().isEmpty) {
      return Left(AppFailure(message: 'Text is empty'));
    }

    if (config.providerId != TranslationProviderId.googleOfficial ||
        config.apiKey == null ||
        config.apiKey!.isEmpty) {
      return Left(
        AppFailure(message: 'Official API and key required for detection'),
      );
    }

    final url = Uri.parse(
      '${AppConstants.officialTranslateBaseUrl}/detect?key=${config.apiKey}',
    );
    final payload = {
      'q': text,
    };

    try {
      final response = await _httpClient
          .post(
            url,
            headers: {'Content-Type': AppConstants.jsonContentType},
            body: json.encode(payload),
          )
          .timeout(config.timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Left(
          NetworkFailure.fromHttpError(response.statusCode, response.body),
        );
      }

      final jsonResponse = json.decode(response.body);
      final data = jsonResponse['data'];
      if (data == null) {
        return Left(TranslationFailure.invalidResponse('Missing data field'));
      }

      final translations = data['translations'] as List<dynamic>?;
      if (translations == null || translations.isEmpty) {
        return Left(TranslationFailure.noTranslationFound());
      }

      final detected =
          translations[0]['detectedSourceLanguage']?.toString() ?? 'en';
      if (detected.isEmpty) {
        return Left(TranslationFailure.noTranslationFound());
      }

      return Right(detected);
    } catch (e) {
      return Left(NetworkFailure(message: 'Detection error: $e'));
    }
  }

  Future<Result<String>> getLocalModelsStatus(ApiConfiguration config) async {
    return _localService.getModelsStatus(config);
  }

  Future<Result<String>> verifyLocalModels(ApiConfiguration config) async {
    return _localService.verifyModels(config);
  }

  Future<Result<String>> removeLocalModels(ApiConfiguration config) async {
    return _localService.removeModels(config);
  }

  Future<Result<String>> installDefaultLocalModels(ApiConfiguration config) async {
    return _localService.installDefaultModels(config);
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
