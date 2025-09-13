library;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:translation_fiesta_flutter/presentation/providers/epub_provider.dart';

class EpubPreviewPane extends StatelessWidget {
  const EpubPreviewPane({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EpubProvider>(
      builder: (context, epubProvider, child) {
        if (epubProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (epubProvider.failure != null) {
          return Center(child: Text('Error: ${epubProvider.failure!.message}'));
        }

        if (epubProvider.book == null) {
          return const Center(child: Text('No EPUB book loaded.'));
        }

        // For now, we'll just display the content of the first chapter.
        // In a real application, we would have a way to select a chapter.
        final chapterContent = epubProvider.book!.chapters.isNotEmpty
            ? epubProvider.book!.chapters.first.content
            : 'No chapters found.';

        return SingleChildScrollView(
          child: Html(
            data: chapterContent,
          ),
        );
      },
    );
  }
}
