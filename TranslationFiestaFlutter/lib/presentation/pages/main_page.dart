/// Clean Code main page with meaningful naming and Single Responsibility
/// Following Material Design principles and Clean Architecture
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
    // Load preferences on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TranslationProvider>().loadPreferences();
      // Set dark mode as default if not already set
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
        title: const Text('Backtranslation (English → ja → English)'),
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
                        showDialog(
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
            // Responsive breakpoints
            bool isWide = constraints.maxWidth > 900;
            bool isMedium =
                constraints.maxWidth > 600 && constraints.maxWidth <= 900;
            bool isNarrow = constraints.maxWidth <= 600;

            if (isWide) {
              // Wide screen layout (> 900px)
              return Column(
                children: [
                  // Main content area
                  Expanded(
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 2,
                          child: InputSection(),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          flex: 3,
                          child: OutputSection(),
                        ),
                      ],
                    ),
                  ),
                  // Control Panel at bottom for wide screens
                  const ControlPanel(),
                ],
              );
            } else if (isMedium) {
              // Medium screen layout (600-900px)
              return Column(
                children: [
                  // Input section
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: const InputSection(),
                  ),
                  const SizedBox(height: 12),
                  // Control Panel
                  const ControlPanel(),
                  const SizedBox(height: 12),
                  // Output section
                  const Expanded(
                    child: OutputSection(),
                  ),
                  const SizedBox(height: 8),
                  const StatusBar(),
                ],
              );
            } else {
              // Narrow screen layout
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
                        } else {
                          return Container(
                            constraints: const BoxConstraints(
                              minHeight: 200,
                              maxHeight: 300,
                            ),
                            child: const InputSection(),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // Control Panel with translate button - always visible
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
            }
          },
        ),
      ),
    );
  }
}
