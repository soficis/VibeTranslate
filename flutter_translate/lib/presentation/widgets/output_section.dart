/// Clean Code output section widget
/// Following Single Responsibility and meaningful naming
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/translation_provider.dart';

/// Output section widget for displaying translation results
/// Single Responsibility: Display intermediate and final translation results
class OutputSection extends StatelessWidget {
  const OutputSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TranslationProvider>();

    return Row(
      children: [
        // Intermediate result
        Expanded(
          child: _TranslationResultCard(
            title: 'Intermediate (ja)',
            content: provider.intermediateText,
            isLoading: provider.isLoading,
          ),
        ),

        const SizedBox(width: 16),

        // Final result
        Expanded(
          child: _TranslationResultCard(
            title: 'Back to English',
            content: provider.finalText,
            isLoading: provider.isLoading,
            showCopyButton: true,
          ),
        ),
      ],
    );
  }
}

/// Individual translation result card
class _TranslationResultCard extends StatelessWidget {
  final String title;
  final String content;
  final bool isLoading;
  final bool showCopyButton;

  const _TranslationResultCard({
    required this.title,
    required this.content,
    required this.isLoading,
    this.showCopyButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TranslationProvider>();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Row(
                  children: [
                    if (content.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${content.length} chars',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ),
                    if (showCopyButton && content.isNotEmpty)
                      IconButton(
                        onPressed: provider.isLoading
                            ? null
                            : provider.copyTextToClipboard,
                        icon: const Icon(Icons.copy),
                        tooltip: 'Copy to clipboard',
                        iconSize: 20,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 180, // Minimum height for larger output areas
                  maxHeight: 350, // Maximum height to maintain layout balance
                ),
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: isLoading && content.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          content.isEmpty
                              ? 'Translation result will appear here...'
                              : content,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 15,
                                    height: 1.6,
                                  ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
