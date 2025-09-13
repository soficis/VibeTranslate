/// Clean Code control panel widget
/// Following Single Responsibility and meaningful naming
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../domain/entities/output_format.dart';
import '../providers/translation_provider.dart';

/// Control panel widget for translation settings and actions
/// Single Responsibility: Handle user controls and settings
class ControlPanel extends StatelessWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TranslationProvider>();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // API Settings Row
            Row(
              children: [
                // Official API Toggle
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Use Official API'),
                    subtitle: const Text('Requires Google Cloud API key'),
                    value: provider.useOfficialApi,
                    onChanged: provider.isLoading
                        ? null
                        : (value) => provider.updateApiConfiguration(
                              value ?? false,
                              provider.apiKey,
                            ),
                    dense: true,
                  ),
                ),

                const SizedBox(width: 16),

                // API Key Input
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: provider.apiKey)
                      ..selection = TextSelection.collapsed(
                        offset: provider.apiKey.length,
                      ),
                    onChanged: (value) => provider.updateApiConfiguration(
                      provider.useOfficialApi,
                      value,
                    ),
                    obscureText: true,
                    enabled: provider.useOfficialApi && !provider.isLoading,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      hintText: 'Enter Google Cloud API key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Format Selection
            Row(
              children: [
                const Text('Output Format:'),
                const SizedBox(width: 12),
                DropdownButton<OutputFormat>(
                  value: provider.outputFormat,
                  items: OutputFormat.values.map((format) {
                    return DropdownMenuItem(
                      value: format,
                      child: Text(format.toString().split('.').last),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      provider.updateOutputFormat(value);
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Action Buttons - responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 400;
                return isWide
                    ? Row(
                        children: [
                          // Translate Button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: provider.isLoading
                                  ? null
                                  : provider.performBackTranslation,
                              child: const Text('Translate'),
                            ),
                          ),

                          const SizedBox(width: 4),

                          // Import Button
                          ElevatedButton(
                            onPressed: provider.isLoading
                                ? null
                                : () async => await _showFilePicker(context),
                            child: const Text('Import'),
                          ),

                          const SizedBox(width: 4),

                          // Save Button
                          ElevatedButton(
                            onPressed: provider.isLoading
                                ? null
                                : () async => await _showSaveDialog(context),
                            child: const Text('Save'),
                          ),

                          const SizedBox(width: 4),

                          // Theme Toggle
                          IconButton(
                            onPressed: () =>
                                provider.updateTheme(!provider.isDarkTheme),
                            icon: Icon(
                              provider.isDarkTheme
                                  ? Icons.light_mode
                                  : Icons.dark_mode,
                            ),
                            tooltip: 'Toggle theme',
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // First row: Translate button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: provider.isLoading
                                  ? null
                                  : provider.performBackTranslation,
                              child: const Text('Translate'),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Second row: Import, Save, Theme
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: provider.isLoading
                                      ? null
                                      : () async =>
                                          await _showFilePicker(context),
                                  child: const Text('Import'),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: provider.isLoading
                                      ? null
                                      : () async =>
                                          await _showSaveDialog(context),
                                  child: const Text('Save'),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: () =>
                                    provider.updateTheme(!provider.isDarkTheme),
                                icon: Icon(
                                  provider.isDarkTheme
                                      ? Icons.light_mode
                                      : Icons.dark_mode,
                                ),
                                tooltip: 'Toggle theme',
                              ),
                            ],
                          ),
                        ],
                      );
              },
            ),
            if (provider.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  /// Show file picker dialog
  Future<void> _showFilePicker(BuildContext context) async {
    final provider = context.read<TranslationProvider>();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'html'],
        dialogTitle: 'Select a file to import',
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final filePath = file.path;

        if (filePath != null) {
          await provider.loadTextFromFile(filePath);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  /// Show save dialog
  Future<void> _showSaveDialog(BuildContext context) async {
    final provider = context.read<TranslationProvider>();

    if (provider.finalText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text to save')),
      );
      return;
    }

    try {
      var outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save translation result',
        fileName: 'backtranslation.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (outputFile == null) {
        return; // User cancelled the save dialog
      }

      // Ensure the file has .txt extension
      if (!outputFile.endsWith('.txt')) {
        outputFile = '$outputFile.txt';
      }

      await provider.saveTextToFile(outputFile);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving file: $e')),
        );
      }
    }
  }
}
