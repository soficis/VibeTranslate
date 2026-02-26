library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/translation.dart';
import '../providers/translation_provider.dart';
import '../widgets/input_section.dart';
import '../widgets/output_section.dart';
import '../widgets/control_panel.dart';
import '../widgets/status_bar.dart';

/// Main application page — unified three-panel layout.
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TranslationFiesta Dart',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Backtranslation EN → JA → EN',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  const Flexible(child: _ProviderSelector()),
                ],
              ),
              const SizedBox(height: 16),

              // Input card
              const Expanded(flex: 2, child: InputSection()),
              const SizedBox(height: 12),

              // Action row
              const ControlPanel(),
              const SizedBox(height: 12),

              // Output panels (side by side on wide, stacked on narrow)
              Expanded(
                flex: 3,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 600) {
                      return const Row(
                        children: [
                          Expanded(child: OutputSection()),
                        ],
                      );
                    }
                    return const OutputSection();
                  },
                ),
              ),
              const SizedBox(height: 8),
              const StatusBar(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Provider dropdown selector in the header.
class _ProviderSelector extends StatelessWidget {
  const _ProviderSelector();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TranslationProvider>();
    return SizedBox(
      width: 280,
      child: DropdownButtonFormField<TranslationProviderId>(
        initialValue: provider.providerId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'PROVIDER',
          labelStyle: Theme.of(context).textTheme.labelSmall,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: TranslationProviderId.values.map((id) {
          return DropdownMenuItem(
            value: id,
            child: Text(id.displayName, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: provider.isLoading
            ? null
            : (value) {
                if (value != null) provider.updateApiConfiguration(value);
              },
      ),
    );
  }
}
