/// Clean Code Flutter application entry point
/// Following Clean Architecture and meaningful naming
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/utils/logger.dart';
import 'presentation/providers/translation_provider.dart';
import 'presentation/pages/main_page.dart';

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
      ],
      child: MaterialApp(
        title: 'Flutter Translate',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const MainPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
