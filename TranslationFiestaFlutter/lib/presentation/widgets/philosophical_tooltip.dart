import 'dart:math';

import 'package:flutter/material.dart';

class PhilosophicalTooltip extends StatelessWidget {
  final Widget child;
  final String message;

  const PhilosophicalTooltip({
    super.key,
    required this.child,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _getPhilosophicalMessage(),
      child: child,
    );
  }

  String _getPhilosophicalMessage() {
    final messages = [
      'Is this truly the gate, or merely a reflection of the desire to enter?',
      'The early bird catches the worm, but the second mouse gets the cheese.',
      'What is the nature of your existence?',
      'The void stares back.',
    ];
    return messages[Random().nextInt(messages.length)];
  }
}
