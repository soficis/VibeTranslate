/// Clean Code status bar widget
/// Following Single Responsibility and meaningful naming
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/translation_provider.dart';

/// Status bar widget for displaying application status
/// Single Responsibility: Display current application status and progress
class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TranslationProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Status text
          Expanded(
            child: Text(
              provider.statusMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Progress indicator when loading
          if (provider.isLoading) ...[
            const SizedBox(width: 12),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],

          // API status indicator
          const SizedBox(width: 12),
          _ApiStatusIndicator(
            useOfficial: provider.useOfficialApi,
            hasApiKey: provider.apiKey.isNotEmpty,
          ),
        ],
      ),
    );
  }
}

/// API status indicator widget
class _ApiStatusIndicator extends StatelessWidget {
  final bool useOfficial;
  final bool hasApiKey;

  const _ApiStatusIndicator({
    required this.useOfficial,
    required this.hasApiKey,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final statusText = _getStatusText();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getStatusIcon(),
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          statusText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    if (!useOfficial) return Colors.green;
    if (hasApiKey) return Colors.green;
    return Colors.orange;
  }

  IconData _getStatusIcon() {
    if (!useOfficial) return Icons.check_circle;
    if (hasApiKey) return Icons.check_circle;
    return Icons.warning;
  }

  String _getStatusText() {
    if (!useOfficial) return 'Unofficial API';
    if (hasApiKey) return 'Official API';
    return 'API Key Required';
  }
}
