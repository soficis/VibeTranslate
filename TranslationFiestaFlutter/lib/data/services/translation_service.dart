library;

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/errors/either.dart';
import '../../core/errors/failure.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/translation.dart';
import 'local_service_launcher.dart';

/// Base class for translation services
/// Single Responsibility: Define common translation behavior
abstract class BaseTranslationService {
  final http.Client httpClient;
  final Logger logger = Logger.instance;

  BaseTranslationService(this.httpClient);

  /// Translate text using the specific service implementation
  Future<Result<TranslationResult>> translate(
    TranslationRequest request,
    ApiConfiguration config,
  );

  /// Get service name for logging
  String get serviceName;
}

/// Local offline translation service (TranslationFiestaLocal)
class LocalTranslationService extends BaseTranslationService {
  static const String _baseUrl = AppConstants.localTranslateBaseUrl;

  LocalTranslationService(super.httpClient);

  @override
  String get serviceName => 'Local Offline';

  @override
  Future<Result<TranslationResult>> translate(
    TranslationRequest request,
    ApiConfiguration config,
  ) async {
    if (request.text.trim().isEmpty) {
      return Right(
        TranslationResult(
          originalText: request.text,
          translatedText: '',
          sourceLanguage: request.sourceLanguage,
          targetLanguage: request.targetLanguage,
          timestamp: DateTime.now(),
        ),
      );
    }

    final healthy = await _ensureServiceAvailable(config);
    if (!healthy) {
      return Left(
        TranslationFailure.localProviderUnavailable(
          'Local service is not running.',
        ),
      );
    }

    final url = _resolveUri('/translate', config);
    final payload = {
      'text': request.text,
      'source_lang': request.sourceLanguage,
      'target_lang': request.targetLanguage,
    };

    try {
      final response = await httpClient
          .post(
            url,
            headers: {'Content-Type': AppConstants.jsonContentType},
            body: json.encode(payload),
          )
          .timeout(config.timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = _extractErrorMessage(response.body);
        return Left(
          TranslationFailure.localProviderUnavailable(message),
        );
      }

      final jsonResponse = json.decode(response.body);
      final translated = jsonResponse['translated_text'];
      if (translated == null || translated.toString().isEmpty) {
        return Left(TranslationFailure.noTranslationFound());
      }

      return Right(
        TranslationResult(
          originalText: request.text,
          translatedText: translated.toString(),
          sourceLanguage: request.sourceLanguage,
          targetLanguage: request.targetLanguage,
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      return Left(
        TranslationFailure.localProviderUnavailable('Local error: $e'),
      );
    }
  }

  Future<bool> _ensureServiceAvailable(ApiConfiguration config) async {
    if (await _isHealthy(config)) {
      return true;
    }
    final started = await tryStartLocalService(
      modelDir: config.localModelDir,
      serviceUrl: config.localServiceUrl,
      autoStart: config.localAutoStart,
    );
    if (!started) {
      return false;
    }
    for (var i = 0; i < 10; i++) {
      if (await _isHealthy(config)) {
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  Future<bool> _isHealthy(ApiConfiguration config) async {
    try {
      final url = _resolveUri('/health', config);
      final response =
          await httpClient.get(url).timeout(config.timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Result<String>> getModelsStatus(ApiConfiguration config) async {
    final healthy = await _ensureServiceAvailable(config);
    if (!healthy) {
      return Left(
        TranslationFailure.localProviderUnavailable(
          'Local service is not running.',
        ),
      );
    }

    try {
      final url = _resolveUri('/models', config);
      final response = await httpClient.get(url).timeout(config.timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = _extractErrorMessage(response.body);
        return Left(TranslationFailure.localProviderUnavailable(message));
      }
      return Right(response.body);
    } catch (e) {
      return Left(
        TranslationFailure.localProviderUnavailable('Local error: $e'),
      );
    }
  }

  Future<Result<String>> verifyModels(ApiConfiguration config) async {
    return _postModelAction('/models/verify', config);
  }

  Future<Result<String>> removeModels(ApiConfiguration config) async {
    return _postModelAction('/models/remove', config);
  }

  Future<Result<String>> installDefaultModels(ApiConfiguration config) async {
    return _postModelAction('/models/install', config);
  }

  Future<Result<String>> _postModelAction(
    String path,
    ApiConfiguration config,
  ) async {
    final healthy = await _ensureServiceAvailable(config);
    if (!healthy) {
      return Left(
        TranslationFailure.localProviderUnavailable(
          'Local service is not running.',
        ),
      );
    }

    try {
      final url = _resolveUri(path, config);
      final response = await httpClient
          .post(
            url,
            headers: {'Content-Type': AppConstants.jsonContentType},
            body: json.encode({}),
          )
          .timeout(config.timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = _extractErrorMessage(response.body);
        return Left(TranslationFailure.localProviderUnavailable(message));
      }
      return Right(response.body);
    } catch (e) {
      return Left(
        TranslationFailure.localProviderUnavailable('Local error: $e'),
      );
    }
  }

  String _resolveBaseUrl(ApiConfiguration config) {
    final override = config.localServiceUrl?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return _baseUrl;
  }

  Uri _resolveUri(String path, ApiConfiguration config) {
    return Uri.parse('${_resolveBaseUrl(config)}$path');
  }

  String _extractErrorMessage(String body) {
    try {
      final jsonResponse = json.decode(body);
      final error = jsonResponse['error'];
      if (error is Map && error['message'] != null) {
        return error['message'].toString();
      }
    } catch (_) {}
    return 'Local provider error';
  }
}

/// Unofficial Google Translate service implementation
/// Single Responsibility: Handle unofficial Google Translate API calls
class UnofficialGoogleTranslateService extends BaseTranslationService {
  static const String _baseUrl = AppConstants.unofficialTranslateBaseUrl;

  UnofficialGoogleTranslateService(super.httpClient);

  @override
  String get serviceName => 'Unofficial Google Translate';

  @override
  Future<Result<TranslationResult>> translate(
    TranslationRequest request,
    ApiConfiguration config,
  ) async {
    try {
      logger.debug(
        'Unofficial translation: ${request.sourceLanguage} -> ${request.targetLanguage} -> ${request.text}',
      );

      final encodedText = Uri.encodeComponent(request.text);
      final url = Uri.parse(
        '$_baseUrl?client=${AppConstants.unofficialApiClient}&sl=${request.sourceLanguage}&tl=${request.targetLanguage}&dt=t&q=$encodedText',
      );

      final response = await httpClient
          .get(url, headers: {'Accept': 'application/json,text/plain,*/*'})
          .timeout(config.timeout);

      logger.debug('Unofficial API Response Status: ${response.statusCode}');
      logger.debug(
          'Unofficial API Response Body Length: ${response.body.length}',);
      logger.debug(
          'Unofficial API Response Preview: ${response.body.substring(0, min(500, response.body.length))}',);

      if (response.statusCode == 429) {
        logger.error('Unofficial API rate limited');
        return Left(TranslationFailure.rateLimited());
      }

      if (response.statusCode == 403) {
        logger.error('Unofficial API blocked');
        return Left(TranslationFailure.blocked());
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorMessage = 'HTTP ${response.statusCode}: ${response.body}';
        logger.error(errorMessage);
        return Left(
          TranslationFailure.invalidResponse(errorMessage),
        );
      }

      // Check if response body is empty or contains error
      if (response.body.isEmpty) {
        logger.error('Empty response from translation API');
        return Left(
            TranslationFailure.invalidResponse('Empty response from API'),);
      }

      final bodyLower = response.body.toLowerCase();
      if (bodyLower.contains('<html') || bodyLower.contains('captcha')) {
        return Left(TranslationFailure.blocked());
      }

      final result = _parseUnofficialResponse(response.body, request);
      return result.map((translationResult) {
        logger.info(
          '$serviceName successful: ${translationResult.characterCount} chars',
        );
        return translationResult;
      });
    } catch (e) {
      final errorMessage = '$serviceName error: $e';
      logger.error(errorMessage);
      return Left(NetworkFailure(message: errorMessage));
    }
  }

  /// Parse the unofficial Google Translate API response
  Result<TranslationResult> _parseUnofficialResponse(
    String responseBody,
    TranslationRequest request,
  ) {
    try {
      logger.debug(
          'Parsing response: ${responseBody.substring(0, min(200, responseBody.length))}...',);

      final jsonResponse = json.decode(responseBody);

      if (jsonResponse is! List || jsonResponse.isEmpty) {
        logger.error('Response is not a valid array: $jsonResponse');
        return Left(
          TranslationFailure.invalidResponse(
            'Response is not a valid array',
          ),
        );
      }

      final translationArray = jsonResponse[0] as List<dynamic>;
      if (translationArray.isEmpty) {
        logger.error('Translation array is empty');
        return Left(TranslationFailure.noTranslationFound());
      }

      final stringBuilder = StringBuffer();

      for (final sentence in translationArray) {
        if (sentence is List && sentence.isNotEmpty) {
          final part = sentence[0]?.toString() ?? '';
          if (part.isNotEmpty) {
            stringBuilder.write(part);
          }
        } else if (sentence is String && sentence.isNotEmpty) {
          stringBuilder.write(sentence);
        }
      }

      final translatedText = stringBuilder.toString().trim();
      if (translatedText.isEmpty) {
        logger.error('Translated text is empty after parsing');
        return Left(TranslationFailure.noTranslationFound());
      }

      logger.debug('Successfully parsed translation: "$translatedText"');

      final result = TranslationResult(
        originalText: request.text,
        translatedText: translatedText,
        sourceLanguage: request.sourceLanguage,
        targetLanguage: request.targetLanguage,
        timestamp: DateTime.now(),
      );

      return Right(result);
    } catch (e) {
      logger.error('Failed to parse response: $e');
      logger.error('Response body: $responseBody');
      return Left(
        TranslationFailure.invalidResponse('Failed to parse response: $e'),
      );
    }
  }
}

/// Mock translation service for testing when APIs are unavailable
/// Single Responsibility: Provide mock translations for development/testing
class MockTranslationService extends BaseTranslationService {
  MockTranslationService(super.httpClient);

  @override
  String get serviceName => 'Mock Translation Service';

  @override
  Future<Result<TranslationResult>> translate(
    TranslationRequest request,
    ApiConfiguration config,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    logger.info(
        'Mock translation: ${request.sourceLanguage} -> ${request.targetLanguage}',);
    logger.info('Mock input text: "${request.text}"');

    // Simple mock translations
    String mockTranslation;
    if (request.targetLanguage == 'ja') {
      mockTranslation = 'こんにちは (Mock: ${request.text})';
    } else if (request.targetLanguage == 'en') {
      mockTranslation = 'Hello (Mock: ${request.text})';
    } else {
      mockTranslation = 'Mock translation: ${request.text}';
    }

    logger.info('Mock output: "$mockTranslation"');

    final result = TranslationResult(
      originalText: request.text,
      translatedText: mockTranslation,
      sourceLanguage: request.sourceLanguage,
      targetLanguage: request.targetLanguage,
      timestamp: DateTime.now(),
    );

    return Right(result);
  }
}
