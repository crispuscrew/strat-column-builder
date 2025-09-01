import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class StrokeLayerSpec {
  final double angleDeg;
  final double spacingMm;
  final double strokeWidthPx;
  final List<double>? dash;
  final Color color;
  final double offsetMm;

  const StrokeLayerSpec({
    required this.angleDeg,
    required this.spacingMm,
    required this.strokeWidthPx,
    this.dash,
    this.color = Colors.black,
    this.offsetMm = 0.0,
  });
}

class GostPatternSpec {
  final List<StrokeLayerSpec> layers;
  final double tileSizeMm;
  final Color? background;

  const GostPatternSpec({
    required this.layers,
    required this.tileSizeMm,
    this.background,
  });
}

double _snapForStroke(double x, double strokeWidth) {
  final bool odd = (strokeWidth.round() % 2) == 1;
  return odd ? (x.floorToDouble() + 0.5) : x.roundToDouble();
}

void _drawDashedLine(
  Canvas canvas,
  Paint paint,
  Offset p0,
  Offset p1,
  List<double>? dash,
) {
  if (dash == null || dash.isEmpty) {
    canvas.drawLine(p0, p1, paint);
    return;
  }

  final double dx = p1.dx - p0.dx;
  final double dy = p1.dy - p0.dy;
  final double len = math.sqrt(dx * dx + dy * dy);
  if (len == 0) return;

  final double dirX = dx / len;
  final double dirY = dy / len;

  double dist = 0;
  int idx = 0;
  bool draw = true;

  while (dist < len) {
    final double seg = dash[idx % dash.length];
    final double take = math.min(seg, len - dist);
    final Offset start = Offset(p0.dx + dirX * dist, p0.dy + dirY * dist);
    final Offset end = Offset(start.dx + dirX * take, start.dy + dirY * take);
    if (draw) canvas.drawLine(start, end, paint);
    dist += seg;
    idx++;
    draw = !draw;
  }
}

Paint buildHatchPaint({
  required GostPatternSpec spec,
  required double pixelsPerMillimeter,
  required double zoom,
}) {
  final double ppm = pixelsPerMillimeter * zoom;
  final int tilePx = (spec.tileSizeMm * ppm).ceil().clamp(4, 2048);

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas tileCanvas =
      Canvas(recorder, Rect.fromLTWH(0, 0, tilePx.toDouble(), tilePx.toDouble()));

  if (spec.background != null) {
    final Paint bg = Paint()..color = spec.background!;
    tileCanvas.drawRect(
      Rect.fromLTWH(0, 0, tilePx.toDouble(), tilePx.toDouble()),
      bg,
    );
  }

  for (final StrokeLayerSpec layer in spec.layers) {
    final double spacingPx = layer.spacingMm * ppm;
    if (spacingPx <= 0.1) continue;

    final double angleRad = layer.angleDeg * math.pi / 180.0;
    final double cosA = math.cos(angleRad);
    final double sinA = math.sin(angleRad);

    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = layer.strokeWidthPx
      ..color = layer.color
      ..isAntiAlias = false;

    final double offsetPx = layer.offsetMm * ppm;
    final double diag = math.sqrt(2) * tilePx;
    final int count = (tilePx / spacingPx).ceil() + 2;

    for (int i = -1; i <= count; i++) {
      final double d = i * spacingPx + offsetPx;

      final double nx = -sinA;
      final double ny = cosA;
      final double cx = tilePx / 2 + nx * (d - tilePx / 2);
      final double cy = tilePx / 2 + ny * (d - tilePx / 2);

      double x0 = cx - cosA * diag / 2;
      double y0 = cy - sinA * diag / 2;
      double x1 = cx + cosA * diag / 2;
      double y1 = cy + sinA * diag / 2;

      x0 = _snapForStroke(x0, p.strokeWidth);
      y0 = _snapForStroke(y0, p.strokeWidth);
      x1 = _snapForStroke(x1, p.strokeWidth);
      y1 = _snapForStroke(y1, p.strokeWidth);

      _drawDashedLine(
        tileCanvas,
        p,
        Offset(x0, y0),
        Offset(x1, y1),
        layer.dash,
      );
    }
  }

  final ui.Picture picture = recorder.endRecording();

  final Shader shader = ui.ImageShader(
    picture.toImageSync(tilePx, tilePx),
    TileMode.repeated,
    TileMode.repeated,
    Matrix4.identity().storage,
  );

  return Paint()
    ..style = PaintingStyle.fill
    ..shader = shader
    ..isAntiAlias = false;
}
