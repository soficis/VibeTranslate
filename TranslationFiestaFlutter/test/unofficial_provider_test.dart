import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:translation_fiesta_flutter/core/errors/failure.dart';
import 'package:translation_fiesta_flutter/data/services/translation_service.dart';
import 'package:translation_fiesta_flutter/domain/entities/translation.dart';

void main() {
  test('unofficial provider parses translation', () async {
    final payload = [
      [
        ['Hello', 'こんにちは', null, null],
      ],
    ];

    final client = MockClient((request) async {
      final body = jsonEncode(payload);
      return http.Response.bytes(
        utf8.encode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final service = UnofficialGoogleTranslateService(client);
    final request = TranslationRequest(
      text: 'こんにちは',
      sourceLanguage: 'ja',
      targetLanguage: 'en',
    );

    final result = await service.translate(
      request,
      ApiConfiguration(providerId: TranslationProviderId.googleUnofficial),
    );

    expect(result.isRight, isTrue);
    expect(result.right.translatedText, equals('Hello'));
  });

  test('unofficial provider maps rate limiting', () async {
    final client = MockClient((request) async => http.Response('too many', 429));
    final service = UnofficialGoogleTranslateService(client);
    final request = TranslationRequest(
      text: 'hello',
      sourceLanguage: 'en',
      targetLanguage: 'ja',
    );

    final result = await service.translate(
      request,
      ApiConfiguration(providerId: TranslationProviderId.googleUnofficial),
    );

    expect(result.isLeft, isTrue);
    expect(result.left, isA<TranslationFailure>());
    expect(result.left.code, equals('rate_limited'));
  });
}
