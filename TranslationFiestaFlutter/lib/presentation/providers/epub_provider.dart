library;

import 'package:flutter/material.dart';
import 'package:translation_fiesta_flutter/core/errors/failure.dart';
import 'package:translation_fiesta_flutter/domain/entities/epub_book.dart';
import 'package:translation_fiesta_flutter/domain/usecases/epub_usecases.dart';

class EpubProvider with ChangeNotifier {
  final LoadEpub loadEpub;
  final GetChapterContent getChapterContent;

  EpubProvider({required this.loadEpub, required this.getChapterContent});

  EpubBook? _book;
  EpubBook? get book => _book;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Failure? _failure;
  Failure? get failure => _failure;

  Future<void> loadBook(String filePath) async {
    _isLoading = true;
    _failure = null;
    notifyListeners();

    final result = await loadEpub(filePath);
    result.fold(
      (failure) {
        _failure = failure;
      },
      (book) {
        _book = book;
      },
    );

    _isLoading = false;
    notifyListeners();
  }
}
