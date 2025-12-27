library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/translation_provider.dart';
import '../providers/epub_provider.dart';
import '../widgets/input_section.dart';
import '../widgets/output_section.dart';
import '../widgets/control_panel.dart';
import '../widgets/status_bar.dart';
import '../widgets/epub_chapter_selection_dialog.dart';
import '../widgets/epub_preview_pane.dart';
import '../widgets/surrealist_file_drop_target.dart';
import '../widgets/surrealist_dialog.dart';
import '../widgets/uncooperative_button.dart';

/// Main application page
/// Single Responsibility: Display the main translation interface
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TranslationProvider>().loadPreferences();
      final provider = context.read<TranslationProvider>();
      if (!provider.isDarkTheme) {
        provider.updateTheme(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backtranslation (English -> Japanese -> English)'),
        centerTitle: true,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.book),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => SurrealistDialog(
                  title: 'Upload ePub',
                  content: SurrealistFileDropTarget(
                    label: 'Drop your ePub here',
                    onFileSelected: (filePath) async {
                      await context.read<EpubProvider>().loadBook(filePath);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        await showDialog(
                          context: context,
                          builder: (context) =>
                              const EpubChapterSelectionDialog(),
                        );
                      }
                    },
                  ),
                  actions: [
                    UncooperativeButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      label: 'Cancel',
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final isMedium =
                constraints.maxWidth > 600 && constraints.maxWidth <= 900;

            if (isWide) {
              return const Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: InputSection(),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: OutputSection(),
                        ),
                      ],
                    ),
                  ),
                  ControlPanel(),
                ],
              );
            }

            if (isMedium) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      constraints: const BoxConstraints(
                        minHeight: 200,
                        maxHeight: 300,
                      ),
                      child: const InputSection(),
                    ),
                    const SizedBox(height: 12),
                    const ControlPanel(),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(
                        minHeight: 250,
                        maxHeight: 400,
                      ),
                      child: const OutputSection(),
                    ),
                    const SizedBox(height: 8),
                    const StatusBar(),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Consumer<EpubProvider>(
                    builder: (context, epubProvider, child) {
                      if (epubProvider.book != null) {
                        return Container(
                          constraints: const BoxConstraints(
                            minHeight: 300,
                            maxHeight: 400,
                          ),
                          child: const EpubPreviewPane(),
                        );
                      }

                      return Container(
                        constraints: const BoxConstraints(
                          minHeight: 200,
                          maxHeight: 300,
                        ),
                        child: const InputSection(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const ControlPanel(),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(
                      minHeight: 300,
                      maxHeight: 400,
                    ),
                    child: const OutputSection(),
                  ),
                  const SizedBox(height: 8),
                  const StatusBar(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
