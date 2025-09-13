library;

import 'package:equatable/equatable.dart';

/// Represents an EPUB book with its chapters
class EpubBook extends Equatable {
  final String title;
  final String author;
  final List<EpubChapter> chapters;

  const EpubBook({
    required this.title,
    required this.author,
    required this.chapters,
  });

  @override
  List<Object?> get props => [title, author, chapters];
}

/// Represents a single chapter in an EPUB book
class EpubChapter extends Equatable {
  final String id;
  final String title;
  final String content;

  const EpubChapter({
    required this.id,
    required this.title,
    required this.content,
  });

  @override
  List<Object?> get props => [id, title, content];
}
