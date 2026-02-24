abstract class Failure {
  final String message;
  final String? code;
  final DateTime timestamp;

  Failure({
    required this.message,
    this.code,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'Failure(message: $message, code: $code, timestamp: $timestamp)';
}

/// Network-related failures
class NetworkFailure extends Failure {
  NetworkFailure({
    required super.message,
    super.code,
    super.timestamp,
  });

  factory NetworkFailure.fromHttpError(int statusCode, String body) {
    return NetworkFailure(
      message: 'HTTP $statusCode: $body',
      code: statusCode.toString(),
    );
  }
}

/// Translation service failures
class TranslationFailure extends Failure {
  TranslationFailure({
    required super.message,
    super.code,
    super.timestamp,
  });

  factory TranslationFailure.noTranslationFound() {
    return TranslationFailure(
      message: 'No translation found in response',
      code: 'no_translation',
    );
  }

  factory TranslationFailure.invalidResponse(String details) {
    return TranslationFailure(
      message: 'Invalid response format: $details',
      code: 'invalid_response',
    );
  }

  factory TranslationFailure.rateLimited() {
    return TranslationFailure(
      message: 'Provider rate limited',
      code: 'rate_limited',
    );
  }

  factory TranslationFailure.blocked() {
    return TranslationFailure(
      message: 'Provider blocked or captcha detected',
      code: 'blocked',
    );
  }
}

/// File operation failures
class FileFailure extends Failure {
  FileFailure({
    required super.message,
    super.code,
    super.timestamp,
  });

  factory FileFailure.fileNotFound(String filePath) {
    return FileFailure(
      message: 'File not found: $filePath',
      code: 'FILE_NOT_FOUND',
    );
  }

  factory FileFailure.permissionDenied(String filePath) {
    return FileFailure(
      message: 'Permission denied: $filePath',
      code: 'PERMISSION_DENIED',
    );
  }

  factory FileFailure.invalidFormat(String filePath, String expectedFormat) {
    return FileFailure(
      message: 'Invalid file format for $filePath. Expected: $expectedFormat',
      code: 'INVALID_FORMAT',
    );
  }
}

/// Generic application failures
class AppFailure extends Failure {
  AppFailure({
    required super.message,
    super.code,
    super.timestamp,
  });

  factory AppFailure.unexpected(String details) {
    return AppFailure(
      message: 'Unexpected error occurred: $details',
      code: 'UNEXPECTED_ERROR',
    );
  }

  factory AppFailure.initializationFailed(String component) {
    return AppFailure(
      message: 'Failed to initialize $component',
      code: 'INIT_FAILED',
    );
  }
}
