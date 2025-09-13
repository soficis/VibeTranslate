/// Clean Code Flutter application entry point
/// Following Clean Architecture and meaningful naming
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/utils/logger.dart';
import 'data/repositories/epub_repository_impl.dart';
import 'domain/usecases/epub_usecases.dart';
import 'presentation/providers/epub_provider.dart';
import 'presentation/providers/translation_provider.dart';
import 'presentation/pages/main_page.dart';
import 'package:translation_fiesta_flutter/presentation/theme/surrealist_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  await Logger.instance.initialize();

  // Log application start
  Logger.instance.info('Flutter Translate application starting');

  runApp(const FlutterTranslateApp());
}

/// Main application widget
/// Single Responsibility: Configure app-wide settings and providers
class FlutterTranslateApp extends StatelessWidget {
  const FlutterTranslateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TranslationProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => EpubProvider(
            loadEpub: LoadEpub(EpubRepositoryImpl()),
            getChapterContent: GetChapterContent(EpubRepositoryImpl()),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Flutter Translate',
        theme: SurrealistTheme.lightTheme,
        darkTheme: SurrealistTheme.darkTheme,
        themeMode: ThemeMode.dark, // Make dark mode the default
        home: const MainPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
