library;

import 'dart:io';
import 'package:epub_parser/epub_parser.dart' as epub;
import 'package:translation_fiesta_flutter/core/errors/either.dart';
import 'package:translation_fiesta_flutter/core/errors/failure.dart';
import 'package:translation_fiesta_flutter/domain/entities/epub_book.dart';
import 'package:translation_fiesta_flutter/domain/repositories/epub_repository.dart';

class EpubRepositoryImpl implements EpubRepository {
  @override
  Future<Result<EpubBook>> loadEpubFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return Left(FileFailure.fileNotFound(filePath));
      }

      final bytes = await file.readAsBytes();
      final epubBook = await epub.EpubReader.readBook(bytes);

      final chapters = epubBook.Chapters?.map((chapter) {
            return EpubChapter(
              id: chapter.Title ?? 'Unknown',
              title: chapter.Title ?? 'Unknown',
              content: chapter.HtmlContent ?? '',
            );
          }).toList() ??
          [];

      return Right(EpubBook(
        title: epubBook.Title ?? 'Unknown Title',
        author: epubBook.Author ?? 'Unknown Author',
        chapters: chapters,
      ));
    } catch (e) {
      return Left(AppFailure.unexpected(e.toString()));
    }
  }

  @override
  Future<Result<String>> getChapterContent(
      EpubBook book, String chapterId) async {
    try {
      final chapter = book.chapters.firstWhere((c) => c.id == chapterId);
      return Right(chapter.content);
    } catch (e) {
      return Left(AppFailure.unexpected(e.toString()));
    }
  }
}
