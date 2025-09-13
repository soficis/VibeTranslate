/// Clean Code repository implementations with Dependency Inversion
/// Following Single Responsibility and meaningful naming
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/errors/either.dart';
import '../../core/errors/failure.dart';
import '../../domain/entities/translation.dart';
import '../../domain/repositories/translation_repository.dart';
import '../services/translation_service.dart';
import '../services/retry_service.dart';

/// Implementation of TranslationRepository interface
/// Single Responsibility: Coordinate translation operations with services
class TranslationRepositoryImpl implements TranslationRepository {
  final UnofficialGoogleTranslateService _unofficialService;
  final OfficialGoogleTranslateService _officialService;
  final RetryService _retryService;
  final http.Client _httpClient;

  TranslationRepositoryImpl(this._httpClient)
      : _unofficialService = UnofficialGoogleTranslateService(_httpClient),
        _officialService = OfficialGoogleTranslateService(_httpClient),
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
    final service =
        config.useOfficialApi ? _officialService : _unofficialService;
    return service.translate(request, config);
  }

  @override
  Future<Result<BackTranslationResult>> performBackTranslation(
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
        String intermediateText) async {
      final secondRequest = TranslationRequest(
        text: intermediateText,
        sourceLanguage: intermediateLanguage,
        targetLanguage: 'en',
      );
      return _translateWithService(secondRequest, config);
    }

    return _retryService.executeBackTranslationWithRetry(
      firstTranslation,
      secondTranslation,
      text,
      config,
      intermediateLanguage: intermediateLanguage,
      statusCallback: (message) {}, // Status handled by calling layer
    );
  }

  @override
  Future<Result<String>> detectLanguage(
    String text,
    ApiConfiguration config,
  ) async {
    if (text.trim().isEmpty) {
      return Left(AppFailure(message: 'Text is empty'));
    }

    if (!config.useOfficialApi ||
        config.apiKey == null ||
        config.apiKey!.isEmpty) {
      return Left(
        AppFailure(message: 'Official API and key required for detection'),
      );
    }

    final url = Uri.parse(
        '${AppConstants.officialTranslateBaseUrl}/detect?key=${config.apiKey}');
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
            NetworkFailure.fromHttpError(response.statusCode, response.body));
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
