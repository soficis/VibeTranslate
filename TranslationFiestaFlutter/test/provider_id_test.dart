import 'package:flutter_test/flutter_test.dart';
import 'package:translation_fiesta_flutter/domain/entities/translation.dart';

void main() {
  test('provider aliases normalize to google_unofficial', () {
    const aliases = <String?>[
      'google_unofficial',
      'unofficial',
      'google_unofficial_free',
      'google_free',
      'googletranslate',
      '',
      '  unofficial  ',
      'GOOGLE_UNOFFICIAL',
      null,
      'unknown_provider',
    ];

    for (final alias in aliases) {
      expect(
        TranslationProviderIdX.fromStorage(alias),
        TranslationProviderId.googleUnofficial,
      );
    }
  });
}
