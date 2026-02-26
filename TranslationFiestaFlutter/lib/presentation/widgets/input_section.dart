/// Input section — unified card with section label.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/translation_provider.dart';

class InputSection extends StatefulWidget {
  const InputSection({super.key});

  @override
  State<InputSection> createState() => _InputSectionState();
}

class _InputSectionState extends State<InputSection> {
  late TextEditingController _controller;
  bool _controllerInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllerInitialized) {
      final provider = context.read<TranslationProvider>();
      _controller = TextEditingController(text: provider.inputText);
      _controllerInitialized = true;
    }
  }

  @override
  void didUpdateWidget(InputSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final provider = context.read<TranslationProvider>();
    if (_controller.text != provider.inputText) {
      _controller.text = provider.inputText;
      _controller.selection = TextSelection.collapsed(
        offset: provider.inputText.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TranslationProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INPUT',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: provider.updateInputText,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Enter text to backtranslate…',
                  contentPadding: EdgeInsets.all(12),
                ),
                enabled: !provider.isLoading,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
