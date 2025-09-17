/// Clean Code translation services with Single Responsibility
/// Following Dependency Inversion and meaningful naming
library;

import 'dart:convert';
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

      final response = await httpClient.get(url).timeout(config.timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorMessage = 'HTTP ${response.statusCode}: ${response.body}';
        logger.error(errorMessage);
        return Left(
          NetworkFailure.fromHttpError(response.statusCode, response.body),
        );
      }

      final result = _parseUnofficialResponse(response.body, request);
      return result.map((translationResult) {
        logger.info(
            '$serviceName successful: ${translationResult.characterCount} chars',);
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
      final jsonResponse = json.decode(responseBody);

      if (jsonResponse is! List || jsonResponse.isEmpty) {
        return Left(TranslationFailure.invalidResponse(
          'Response is not a valid array',
        ),);
      }

      final translationArray = jsonResponse[0] as List<dynamic>;
      if (translationArray.isEmpty) {
        return Left(TranslationFailure.noTranslationFound());
      }

      final stringBuilder = StringBuffer();

      for (final sentence in translationArray) {
        if (sentence is List && sentence.isNotEmpty) {
          final part = sentence[0]?.toString() ?? '';
          if (part.isNotEmpty) {
            stringBuilder.write(part);
          }
        }
      }

      final translatedText = stringBuilder.toString();
      if (translatedText.isEmpty) {
        return Left(TranslationFailure.noTranslationFound());
      }

      final result = TranslationResult(
        originalText: request.text,
        translatedText: translatedText,
        sourceLanguage: request.sourceLanguage,
        targetLanguage: request.targetLanguage,
        timestamp: DateTime.now(),
      );

      return Right(result);
    } catch (e) {
      return Left(
        TranslationFailure.invalidResponse('Failed to parse response: $e'),
      );
    }
  }
}

/// Official Google Cloud Translation service implementation
/// Single Responsibility: Handle official Google Cloud Translation API calls
class OfficialGoogleTranslateService extends BaseTranslationService {
  static const String _baseUrl = AppConstants.officialTranslateBaseUrl;

  OfficialGoogleTranslateService(super.httpClient);

  @override
  String get serviceName => 'Official Google Cloud Translation';

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
        'q': [request.text],
        'target': request.targetLanguage,
        'source':
            request.sourceLanguage == 'auto' ? null : request.sourceLanguage,
        'format': 'text',
      };

      final headers = {'Content-Type': AppConstants.jsonContentType};
      final body = json.encode(payload);

      final response = await httpClient
          .post(url, headers: headers, body: body)
          .timeout(config.timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorMessage = 'HTTP ${response.statusCode}: ${response.body}';
        logger.error(errorMessage);
        return Left(
          NetworkFailure.fromHttpError(response.statusCode, response.body),
        );
      }

      final result = _parseOfficialResponse(response.body, request);
      return result.map((translationResult) {
        logger.info(
            '$serviceName successful: ${translationResult.characterCount} chars',);
        return translationResult;
      });
    } catch (e) {
      final errorMessage = '$serviceName error: $e';
      logger.error(errorMessage);
      return Left(NetworkFailure(message: errorMessage));
    }
  }

  /// Parse the official Google Cloud Translation API response
  Result<TranslationResult> _parseOfficialResponse(
    String responseBody,
    TranslationRequest request,
  ) {
    try {
      final jsonResponse = json.decode(responseBody);

      final data = jsonResponse['data'];
      if (data == null) {
        return Left(TranslationFailure.invalidResponse('Missing data field'));
      }

      final translations = data['translations'] as List<dynamic>?;
      if (translations == null || translations.isEmpty) {
        return Left(TranslationFailure.noTranslationFound());
      }

      final translatedText =
          translations[0]['translatedText']?.toString() ?? '';
      if (translatedText.isEmpty) {
        return Left(TranslationFailure.noTranslationFound());
      }

      final result = TranslationResult(
        originalText: request.text,
        translatedText: translatedText,
        sourceLanguage: request.sourceLanguage,
        targetLanguage: request.targetLanguage,
        timestamp: DateTime.now(),
      );

      return Right(result);
    } catch (e) {
      return Left(
        TranslationFailure.invalidResponse('Failed to parse response: $e'),
      );
    }
  }
}
