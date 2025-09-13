/// Clean Code file repository implementation
/// Following Single Responsibility and meaningful naming
library;

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../../core/constants/app_constants.dart';
import '../../core/errors/either.dart';
import '../../core/errors/failure.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/translation_repository.dart';

/// Implementation of FileRepository interface
/// Single Responsibility: Handle file operations and text extraction
class FileRepositoryImpl implements FileRepository {
  final Logger logger = Logger.instance;

  @override
  List<String> get supportedExtensions => AppConstants.supportedFileExtensions;

  @override
  bool isFileExtensionSupported(String extension) {
    final normalizedExtension = extension.toLowerCase();
    return supportedExtensions.contains(normalizedExtension);
  }

  @override
  Future<Result<String>> loadTextFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return Left(FileFailure.fileNotFound(filePath));
      }

      final extension = path.extension(filePath).toLowerCase();
      final rawContent = await file.readAsString(encoding: utf8);

      logger.debug(
          'Loaded raw content from $filePath: ${rawContent.length} chars');

      final processedContent = await _processFileContent(rawContent, extension);
      logger.info(
          'Successfully loaded file: $filePath (${processedContent.length} chars)');

      return Right(processedContent);
    } catch (e) {
      final errorMessage = 'Failed to load file $filePath: $e';
      logger.error(errorMessage);

      if (e is FileSystemException) {
        if (e.osError?.errorCode == 2) {
          return Left(FileFailure.fileNotFound(filePath));
        } else if (e.osError?.errorCode == 5) {
          return Left(FileFailure.permissionDenied(filePath));
        }
      }

      return Left(FileFailure(message: errorMessage));
    }
  }

  @override
  Future<Result<void>> saveTextToFile(String content, String filePath) async {
    try {
      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsString(content, encoding: utf8);

      logger
          .info('Successfully saved file: $filePath (${content.length} chars)');
      return const Right(null);
    } catch (e) {
      final errorMessage = 'Failed to save file $filePath: $e';
      logger.error(errorMessage);

      if (e is FileSystemException && e.osError?.errorCode == 5) {
        return Left(FileFailure.permissionDenied(filePath));
      }

      return Left(FileFailure(message: errorMessage));
    }
  }

  @override
  Result<String> extractTextFromHtml(String htmlContent) {
    try {
      // Remove script, style, code, and pre blocks using regex
      final scriptPattern = RegExp(r'<script[^>]*>.*?</script>',
          caseSensitive: false, dotAll: true);
      final stylePattern = RegExp(r'<style[^>]*>.*?</style>',
          caseSensitive: false, dotAll: true);
      final codePattern =
          RegExp(r'<code[^>]*>.*?</code>', caseSensitive: false, dotAll: true);
      final prePattern =
          RegExp(r'<pre[^>]*>.*?</pre>', caseSensitive: false, dotAll: true);

      var processedContent = htmlContent;
      processedContent = processedContent.replaceAll(scriptPattern, '');
      processedContent = processedContent.replaceAll(stylePattern, '');
      processedContent = processedContent.replaceAll(codePattern, '');
      processedContent = processedContent.replaceAll(prePattern, '');

      // Remove all remaining HTML tags
      final tagPattern = RegExp(r'<[^>]+>');
      processedContent = processedContent.replaceAll(tagPattern, '');

      // Normalize whitespace
      final whitespacePattern = RegExp(r'\s+');
      processedContent = processedContent.replaceAll(whitespacePattern, ' ');

      final extractedText = processedContent.trim();

      logger.debug(
        'Extracted text from HTML: ${htmlContent.length} chars -> ${extractedText.length} chars',
      );

      return Right(extractedText);
    } catch (e) {
      final errorMessage = 'HTML parsing failed: $e';
      logger.error(errorMessage);
      return Left(FileFailure.invalidFormat(
          'HTML content', 'Failed to parse HTML: $e'));
    }
  }

  /// Process file content based on file type
  Future<String> _processFileContent(
      String rawContent, String extension) async {
    switch (extension) {
      case '.html':
        final htmlResult = extractTextFromHtml(rawContent);
        return htmlResult
            .getOrElse(() => rawContent); // Fallback to raw content
      case '.md':
      case '.txt':
      default:
        return rawContent.trim();
    }
  }
}

/// Factory for creating FileRepository instances
class FileRepositoryFactory {
  static FileRepository create() {
    return FileRepositoryImpl();
  }
}
