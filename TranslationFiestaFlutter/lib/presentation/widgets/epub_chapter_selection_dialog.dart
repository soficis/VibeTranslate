library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:translation_fiesta_flutter/presentation/providers/epub_provider.dart';
import 'package:translation_fiesta_flutter/presentation/providers/translation_provider.dart';
import 'package:translation_fiesta_flutter/presentation/widgets/surrealist_dialog.dart';
import 'package:translation_fiesta_flutter/presentation/widgets/uncooperative_button.dart';

class EpubChapterSelectionDialog extends StatelessWidget {
  const EpubChapterSelectionDialog({super.key});

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

        return SurrealistDialog(
          title: epubProvider.book!.title,
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: epubProvider.book!.chapters.length,
              itemBuilder: (context, index) {
                final chapter = epubProvider.book!.chapters[index];
                return ListTile(
                  title: Text(chapter.title),
                  onTap: () async {
                    // Load chapter content and set it as input text
                    final result = await epubProvider.getChapterContent(
                      epubProvider.book!,
                      chapter.id,
                    );

                    if (context.mounted) {
                      result.fold(
                        (failure) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to load chapter: ${failure.message}',
                              ),
                            ),
                          );
                        },
                        (content) {
                          // Set the chapter content as input text for translation
                          context
                              .read<TranslationProvider>()
                              .updateInputText(content);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Chapter "${chapter.title}" loaded for translation',
                              ),
                            ),
                          );
                        },
                      );
                      Navigator.of(context).pop();
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            UncooperativeButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              label: 'Close',
            ),
          ],
        );
      },
    );
  }
}
