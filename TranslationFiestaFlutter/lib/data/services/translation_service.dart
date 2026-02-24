library;

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/errors/either.dart';
import '../../core/errors/failure.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/translation.dart';

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

      final response = await httpClient.get(
        url,
        headers: {
          'Accept': 'application/json,text/plain,*/*',
        },
      ).timeout(config.timeout);

      logger.debug('Unofficial API Response Status: ${response.statusCode}');
      logger.debug(
        'Unofficial API Response Body Length: ${response.body.length}',
      );
      logger.debug(
        'Unofficial API Response Preview: ${response.body.substring(0, min(500, response.body.length))}',
      );

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
          TranslationFailure.invalidResponse('Empty response from API'),
        );
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
        'Parsing response: ${responseBody.substring(0, min(200, responseBody.length))}...',
      );

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
      'Mock translation: ${request.sourceLanguage} -> ${request.targetLanguage}',
    );
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
