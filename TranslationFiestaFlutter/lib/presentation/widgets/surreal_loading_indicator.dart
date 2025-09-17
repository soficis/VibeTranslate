import 'dart:math';

import 'package:flutter/material.dart';

class SurrealLoadingIndicator extends StatefulWidget {
  const SurrealLoadingIndicator({super.key});

  @override
  SurrealLoadingIndicatorState createState() => SurrealLoadingIndicatorState();
}

class SurrealLoadingIndicatorState extends State<SurrealLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _SurrealPainter(_controller.value),
          child: const SizedBox(
            width: 100,
            height: 100,
          ),
        );
      },
    );
  }
}

class _SurrealPainter extends CustomPainter {
  final double progress;

  _SurrealPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke;

    // Melting Clock
    final angle = 2 * pi * progress;
    final x = center.dx + radius * cos(angle);
    final y = center.dy + radius * sin(angle);
    canvas.drawCircle(center, radius, paint);
    canvas.drawLine(center, Offset(x, y), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
