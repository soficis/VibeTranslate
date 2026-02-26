/// Output section — two side-by-side cards: Intermediate (JA) and Result (EN).
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:provider/provider.dart';
import '../../domain/entities/output_format.dart';
import '../providers/translation_provider.dart';

class OutputSection extends StatelessWidget {
  const OutputSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TranslationProvider>();

    return Row(
      children: [
        Expanded(
          child: _OutputCard(
            label: 'INTERMEDIATE (JA)',
            content: provider.intermediateText,
            isLoading: provider.isLoading,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _OutputCard(
            label: 'RESULT (EN)',
            content: provider.finalText,
            isLoading: provider.isLoading,
          ),
        ),
      ],
    );
  }
}

class _OutputCard extends StatelessWidget {
  final String label;
  final String content;
  final bool isLoading;

  const _OutputCard({
    required this.label,
    required this.content,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TranslationProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                ),
                child: isLoading && content.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: _buildContent(context, provider, content),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    TranslationProvider provider,
    String text,
  ) {
    if (text.isEmpty) {
      return Text(
        'Translation will appear here…',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    switch (provider.outputFormat) {
      case OutputFormat.markdown:
        return MarkdownBody(data: text);
      case OutputFormat.html:
        return SelectableText(
          _stripHtml(text),
          style: const TextStyle(fontSize: 14, height: 1.6),
        );
      case OutputFormat.plain:
        return SelectableText(
          text,
          style: const TextStyle(fontSize: 14, height: 1.6),
        );
    }
  }

  String _stripHtml(String text) {
    try {
      final document = html_parser.parse(text);
      return html_parser.parse(document.body?.text).documentElement?.text ?? '';
    } catch (_) {
      return text;
    }
  }
}
