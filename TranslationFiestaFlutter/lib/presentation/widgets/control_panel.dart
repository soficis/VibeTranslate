library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../domain/entities/output_format.dart';
import '../../domain/entities/translation.dart';
import '../providers/translation_provider.dart';

/// Control panel widget for translation settings and actions
/// Single Responsibility: Handle user controls and settings
class ControlPanel extends StatefulWidget {
  const ControlPanel({super.key});

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  late TextEditingController _apiKeyController;
  late TextEditingController _localUrlController;
  late TextEditingController _localDirController;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _localUrlController = TextEditingController();
    _localDirController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<TranslationProvider>();
    _apiKeyController.text = provider.apiKey;
    _localUrlController.text = provider.localServiceUrl;
    _localDirController.text = provider.localModelDir;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _localUrlController.dispose();
    _localDirController.dispose();
    super.dispose();
  }

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
                // Provider selector
                Expanded(
                  child: DropdownButtonFormField<TranslationProviderId>(
                    initialValue: provider.providerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Provider',
                      border: OutlineInputBorder(),
                    ),
                    items: TranslationProviderId.values.map((providerId) {
                      return DropdownMenuItem(
                        value: providerId,
                        child: Text(
                          providerId.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: provider.isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              provider.updateApiConfiguration(
                                value,
                                provider.apiKey,
                              );
                            }
                          },
                  ),
                ),

                const SizedBox(width: 16),

                // API Key Input
                Expanded(
                  child: TextField(
                    controller: _apiKeyController,
                    onChanged: (value) => provider.updateApiConfiguration(
                      provider.providerId,
                      value,
                    ),
                    obscureText: true,
                    enabled:
                        provider.providerId.isOfficial && !provider.isLoading,
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

            if (provider.providerId == TranslationProviderId.local) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Local Model Manager',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _localUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Service URL',
                      hintText: 'http://127.0.0.1:5055',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _localDirController,
                    decoration: const InputDecoration(
                      labelText: 'Model Directory',
                      hintText: 'Optional override path',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    title: const Text('Auto-start local service'),
                    value: provider.localAutoStart,
                    onChanged: provider.isLoading
                        ? null
                        : (value) async {
                            await provider.updateLocalSettings(
                              serviceUrl: _localUrlController.text,
                              modelDir: _localDirController.text,
                              autoStart: value,
                            );
                          },
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: provider.isLoading
                            ? null
                            : () async {
                                await provider.updateLocalSettings(
                                  serviceUrl: _localUrlController.text,
                                  modelDir: _localDirController.text,
                                  autoStart: provider.localAutoStart,
                                );
                                await provider.refreshLocalModels();
                              },
                        child: const Text('Save'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: provider.isLoading
                            ? null
                            : provider.installDefaultLocalModels,
                        child: const Text('Install Default'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: provider.isLoading
                            ? null
                            : provider.refreshLocalModels,
                        child: const Text('Refresh'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: provider.isLoading
                            ? null
                            : provider.verifyLocalModels,
                        child: const Text('Verify'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: provider.isLoading
                            ? null
                            : provider.removeLocalModels,
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                  if (provider.localModelStatus.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      provider.localModelStatus,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
            ],

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

                          // Second row: Import and Save buttons
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
                            ],
                          ),

                          const SizedBox(height: 4),

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
