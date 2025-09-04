/// Clean Code main page with meaningful naming and Single Responsibility
/// Following Material Design principles and Clean Architecture
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/translation_provider.dart';
import '../widgets/input_section.dart';
import '../widgets/output_section.dart';
import '../widgets/control_panel.dart';
import '../widgets/status_bar.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backtranslation (English → ja → English)'),
        centerTitle: true,
        elevation: 2,
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Input section - moderate size
              Expanded(
                flex: 2,
                child: InputSection(),
              ),

              const SizedBox(height: 16),

              // Control panel
              ControlPanel(),

              const SizedBox(height: 16),

              // Output sections - now larger to accommodate bigger text areas
              Expanded(
                flex: 3,
                child: OutputSection(),
              ),

              const SizedBox(height: 8),

              // Status bar
              StatusBar(),
            ],
          ),
        ),
      ),
    );
  }
}
