import 'package:flutter/material.dart';

class CanvasView extends StatelessWidget {
  final CustomPainter? painter;

  const CanvasView({super.key, required this.painter});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: painter,
      child: const SizedBox.expand(),
    );
  }
}
