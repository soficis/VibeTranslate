import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class UncooperativeButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;

  const UncooperativeButton({
    super.key,
    required this.onPressed,
    required this.label,
  });

  @override
  _UncooperativeButtonState createState() => _UncooperativeButtonState();
}

class _UncooperativeButtonState extends State<UncooperativeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  bool _isVisible = true;
  String _currentLabel = '';

  @override
  void initState() {
    super.initState();
    _currentLabel = widget.label;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.1, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticIn,
    ),);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    final random = Random();
    final action = random.nextInt(4);

    switch (action) {
      case 0:
        // Shifting Target
        _controller.forward().then((_) => _controller.reverse());
        break;
      case 1:
        // Ephemeral Button
        setState(() {
          _isVisible = false;
        });
        Timer(const Duration(seconds: 2), () {
          setState(() {
            _isVisible = true;
          });
        });
        break;
      case 2:
        // Misleading Label
        setState(() {
          _currentLabel = 'Do Not Press';
        });
        Timer(const Duration(seconds: 2), () {
          setState(() {
            _currentLabel = widget.label;
          });
        });
        break;
      case 3:
        // Delayed Response
        Timer(const Duration(seconds: 1), widget.onPressed);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: _isVisible,
      child: SlideTransition(
        position: _offsetAnimation,
        child: ElevatedButton(
          onPressed: _handleTap,
          child: Text(_currentLabel),
        ),
      ),
    );
  }
}
