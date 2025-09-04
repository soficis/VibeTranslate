/// Clean Code control panel widget
/// Following Single Responsibility and meaningful naming
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
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
        padding: const EdgeInsets.all(16),
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

            // Action Buttons Row
            Row(
              children: [
                // Backtranslate Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: provider.isLoading
                        ? null
                        : provider.performBackTranslation,
                    icon: provider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.translate),
                    label: const Text('Backtranslate'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Import Button
                ElevatedButton.icon(
                  onPressed: provider.isLoading
                      ? null
                      : () async => await _showFilePicker(context),
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import'),
                ),

                const SizedBox(width: 12),

                // Save Button
                ElevatedButton.icon(
                  onPressed: provider.isLoading || provider.finalText.isEmpty
                      ? null
                      : () async => await _showSaveDialog(context),
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),

                const SizedBox(width: 12),

                // Theme Toggle
                IconButton(
                  onPressed: () => provider.updateTheme(!provider.isDarkTheme),
                  icon: Icon(
                    provider.isDarkTheme ? Icons.light_mode : Icons.dark_mode,
                  ),
                  tooltip: 'Toggle theme',
                ),
              ],
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
      FilePickerResult? result = await FilePicker.platform.pickFiles(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
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
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save translation result',
        fileName: 'backtranslation.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (outputFile != null) {
        // Ensure the file has .txt extension
        if (!outputFile.endsWith('.txt')) {
          outputFile = '$outputFile.txt';
        }

        await provider.saveTextToFile(outputFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving file: $e')),
      );
    }
  }
}
