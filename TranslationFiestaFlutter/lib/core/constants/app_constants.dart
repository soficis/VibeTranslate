class AppConstants {
  // Translation Configuration
  static const String defaultIntermediateLanguageCode = 'ja';
  static const String defaultSourceLanguageCode = 'en';

  // API Configuration
  static const String unofficialTranslateBaseUrl =
      'https://translate.googleapis.com/translate_a/single';
  static const String unofficialApiClient = 'gtx';

  // Retry Configuration
  static const int maxRetryAttempts = 4;
  static const int baseRetryDelayMs = 1000;
  static const double retryBackoffMultiplier = 2;
  static const int maxRetryJitterMs = 300;

  // HTTP Configuration
  static const int httpTimeoutSeconds = 30;
  static const String jsonContentType = 'application/json';

  // File Configuration
  static const String logFileName = 'TranslationFiestaFlutter.log';
  static const String defaultExportFileName = 'backtranslation.txt';
  static const List<String> supportedFileExtensions = ['.txt', '.md', '.html'];

  // UI Configuration
  static const double defaultBorderRadius = 8;
  static const double defaultPadding = 16;
  static const double defaultSpacing = 12;
  static const int maxInputTextLength = 10000;

  // Theme Configuration
  static const String themePreferenceKey = 'isDarkTheme';
  static const String providerIdPreferenceKey = 'providerId';

  // Animation Configuration
  static const int progressAnimationDurationMs = 300;
  static const int translationFadeDurationMs = 500;
}
