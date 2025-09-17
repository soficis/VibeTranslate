/// Clean Code translation services with Single Responsibility
/// Following Dependency Inversion and meaningful naming
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
        '$_baseUrl?client=${AppConstants.unofficialApiClient}&sl=${request.sourceLanguage}&tl=${request.targetLanguage}&dt=t&dt=bd&dt=ex&dt=ld&dt=md&dt=qca&dt=rw&dt=rm&dt=ss&dt=t&dt=at&ie=UTF-8&oe=UTF-8&otf=1&ssel=0&tsel=0&kc=7&q=$encodedText',
      );

      final response = await httpClient.get(url).timeout(config.timeout);

      logger.debug('Unofficial API Response Status: ${response.statusCode}');
      logger.debug(
          'Unofficial API Response Body Length: ${response.body.length}');
      logger.debug(
          'Unofficial API Response Preview: ${response.body.substring(0, min(500, response.body.length))}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorMessage = 'HTTP ${response.statusCode}: ${response.body}';
        logger.error(errorMessage);
        return Left(
          NetworkFailure.fromHttpError(response.statusCode, response.body),
        );
      }

      // Check if response body is empty or contains error
      if (response.body.isEmpty) {
        logger.error('Empty response from translation API');
        return Left(
            TranslationFailure.invalidResponse('Empty response from API'));
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
          'Parsing response: ${responseBody.substring(0, min(200, responseBody.length))}...');

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
        'Mock translation: ${request.sourceLanguage} -> ${request.targetLanguage}');
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

/// Official Google Translate service implementation
/// Single Responsibility: Handle official Google Translate API calls
class OfficialGoogleTranslateService extends BaseTranslationService {
  static const String _baseUrl = AppConstants.officialTranslateBaseUrl;

  OfficialGoogleTranslateService(super.httpClient);

  @override
  String get serviceName => 'Official Google Translate';

  @override
  Future<Result<TranslationResult>> translate(
    TranslationRequest request,
    ApiConfiguration config,
  ) async {
    try {
      if (config.apiKey == null || config.apiKey!.isEmpty) {
        return Left(TranslationFailure.apiKeyRequired());
      }

      logger.debug(
        'Official translation: ${request.sourceLanguage} -> ${request.targetLanguage} -> ${request.text}',
      );

      final url = Uri.parse('$_baseUrl?key=${config.apiKey}');
      final payload = {
        'q': request.text,
        'source': request.sourceLanguage,
        'target': request.targetLanguage,
        'format': 'text',
      };

      final response = await httpClient
          .post(
            url,
            headers: {'Content-Type': AppConstants.jsonContentType},
            body: json.encode(payload),
          )
          .timeout(config.timeout);

      logger.debug('API Response Status: ${response.statusCode}');
      logger.debug('API Response Body Length: ${response.body.length}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorMessage = 'HTTP ${response.statusCode}: ${response.body}';
        logger.error(errorMessage);
        return Left(
          NetworkFailure.fromHttpError(response.statusCode, response.body),
        );
      }

      // Check if response body is empty or contains error
      if (response.body.isEmpty) {
        logger.error('Empty response from official translation API');
        return Left(
            TranslationFailure.invalidResponse('Empty response from API'));
      }

      final result = _parseOfficialResponse(response.body, request);
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

  /// Parse the official Google Translate API response
  Result<TranslationResult> _parseOfficialResponse(
    String responseBody,
    TranslationRequest request,
  ) {
    try {
      logger.debug(
          'Parsing official response: ${responseBody.substring(0, min(200, responseBody.length))}...');

      final jsonResponse = json.decode(responseBody);

      // Check for error in response
      if (jsonResponse['error'] != null) {
        final error = jsonResponse['error'];
        final message = error['message'] ?? 'Unknown error';
        logger.error('Official API error: $message');
        return Left(TranslationFailure.invalidResponse(message));
      }

      final data = jsonResponse['data'];
      if (data == null) {
        logger.error('Missing data field in official API response');
        return Left(TranslationFailure.invalidResponse('Missing data field'));
      }

      final translations = data['translations'] as List<dynamic>?;
      if (translations == null || translations.isEmpty) {
        logger.error('No translations found in official API response');
        return Left(TranslationFailure.noTranslationFound());
      }

      final translatedText =
          translations[0]['translatedText']?.toString() ?? '';
      if (translatedText.isEmpty) {
        logger.error('Translated text is empty in official API response');
        return Left(TranslationFailure.noTranslationFound());
      }

      logger
          .debug('Successfully parsed official translation: "$translatedText"');

      final result = TranslationResult(
        originalText: request.text,
        translatedText: translatedText,
        sourceLanguage: request.sourceLanguage,
        targetLanguage: request.targetLanguage,
        timestamp: DateTime.now(),
      );

      return Right(result);
    } catch (e) {
      logger.error('Failed to parse official response: $e');
      logger.error('Response body: $responseBody');
      return Left(
        TranslationFailure.invalidResponse('Failed to parse response: $e'),
      );
    }
  }
}
