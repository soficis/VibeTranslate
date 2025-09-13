library;

import '../../core/errors/either.dart';
import '../entities/epub_book.dart';

/// Repository interface for EPUB operations
/// Single Responsibility: Define EPUB data access contract
abstract class EpubRepository {
  /// Load EPUB content from a file
  Future<Result<EpubBook>> loadEpubFromFile(String filePath);

  /// Get content of a specific chapter
  Future<Result<String>> getChapterContent(EpubBook book, String chapterId);
}
