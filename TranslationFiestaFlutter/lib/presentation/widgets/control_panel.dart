library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/utils/app_paths.dart';
// domain entities used by provider indirectly
import '../providers/translation_provider.dart';

/// Simplified control panel — hero action button + secondary actions.
class ControlPanel extends StatefulWidget {
  const ControlPanel({super.key});

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TranslationProvider>();

    return Row(
      children: [
        // Hero Backtranslate button (pill shape)
        ElevatedButton(
          onPressed:
              provider.isLoading ? null : provider.performBackTranslation,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          child: Text(provider.isLoading ? 'Translating…' : '⦿  Backtranslate'),
        ),

        const SizedBox(width: 8),

        // Import
        OutlinedButton(
          onPressed: provider.isLoading
              ? null
              : () async => await _showFilePicker(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Import'),
        ),

        const SizedBox(width: 8),

        // Export
        OutlinedButton(
          onPressed: provider.isLoading
              ? null
              : () async => await _showSaveDialog(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Export'),
        ),

        const Spacer(),

        // Loading indicator
        if (provider.isLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

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
        initialDirectory: AppPaths.instance.exportsDirectory.path,
      );

      if (outputFile == null) {
        return;
      }

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
