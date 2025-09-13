import 'package:flutter/material.dart';
import 'philosophical_tooltip.dart';

class SurrealistDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const SurrealistDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: PhilosophicalTooltip(
        message: title,
        child: Text(title),
      ),
      content: content,
      actions: actions,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
    );
  }
}
