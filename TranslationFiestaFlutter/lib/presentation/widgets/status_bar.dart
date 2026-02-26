library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/translation_provider.dart';

/// Minimal status bar — status text + loading indicator.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  static const _amber = Color(0xFFF59E0B);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _muted = Color(0xFF8B95A5);

  Color _statusColor(String message, bool isLoading) {
    if (isLoading) return _amber;
    final lower = message.toLowerCase();
    if (lower.contains('error') || lower.contains('fail')) return _red;
    if (lower.contains('done') || lower.contains('complet')) return _green;
    return _muted;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TranslationProvider>();
    final color = _statusColor(provider.statusMessage, provider.isLoading);

    return Row(
      children: [
        if (provider.isLoading)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
          ),
        Expanded(
          child: Text(
            provider.statusMessage.isEmpty ? 'Ready' : provider.statusMessage,
            style: TextStyle(fontSize: 13, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
