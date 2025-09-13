library;

import 'package:translation_fiesta_flutter/core/errors/either.dart';
import 'package:translation_fiesta_flutter/domain/entities/epub_book.dart';
import 'package:translation_fiesta_flutter/domain/repositories/epub_repository.dart';

class LoadEpub {
  final EpubRepository repository;

  LoadEpub(this.repository);

  Future<Result<EpubBook>> call(String filePath) {
    return repository.loadEpubFromFile(filePath);
  }
}

class GetChapterContent {
  final EpubRepository repository;

  GetChapterContent(this.repository);

  Future<Result<String>> call(EpubBook book, String chapterId) {
    return repository.getChapterContent(book, chapterId);
  }
}
