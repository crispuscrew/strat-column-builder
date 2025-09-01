import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/models.dart';

class PatternRenderer {
  final double pixelsPerMillimeter;

  const PatternRenderer({required this.pixelsPerMillimeter});

  void drawPattern(
    Canvas canvas,
    Rect rect,
    GostPatternSpec pattern, {
    Color? colorHint,
  }) {
    if (rect.isEmpty) return;
    canvas.save();
    canvas.clipRect(rect);

    final Paint basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = colorHint ?? Colors.black
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = false;

    for (final StrokeLayerSpec layerSpec in pattern.layers) {
      _drawStrokeLayerWorldAnchored(canvas, rect, basePaint, layerSpec);
    }
    canvas.restore();
  }

  void _drawStrokeLayerWorldAnchored(
    Canvas canvas,
    Rect rect,
    Paint basePaint,
    StrokeLayerSpec layerSpec,
  ) {
    final double stepPixels = (layerSpec.stepMm * pixelsPerMillimeter).abs();
    final double thicknessPixels =
        (layerSpec.thicknessMm * pixelsPerMillimeter).clamp(0.5, 10.0);
    if (stepPixels < 0.5) return;

    final double angleRadians = layerSpec.angleDeg * math.pi / 180.0;

    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thicknessPixels
      ..strokeCap = StrokeCap.butt
      ..color = basePaint.color
      ..isAntiAlias = false;

    final Rect rotatedCoverage = _rotatedAxisAlignedBounds(rect, angleRadians);

    canvas.save();
    canvas.rotate(angleRadians);

    final double horizontalStart = rotatedCoverage.left - stepPixels * 2.0;
    final double horizontalEnd = rotatedCoverage.right + stepPixels * 2.0;

    final bool oddStrokeWidth = strokePaint.strokeWidth.round().isOdd;
    final double pixelSnapOffset = oddStrokeWidth ? 0.5 : 0.0;

    final double rawYStart =
        rotatedCoverage.top - rotatedCoverage.top % stepPixels - stepPixels * 2.0;
    final double rawYEnd = rotatedCoverage.bottom + stepPixels * 2.0;

    final bool useShortSegments =
        _shouldUseShortSegments(layerSpec, stepPixels);

    for (double logicalY = rawYStart;
        logicalY <= rawYEnd;
        logicalY += stepPixels) {
      final double snappedY = (logicalY + pixelSnapOffset).floorToDouble();

      if (!useShortSegments) {
        canvas.drawLine(
          Offset(horizontalStart, snappedY),
          Offset(horizontalEnd, snappedY),
          strokePaint,
        );
        continue;
      }

      final double segmentLengthPixels =
          _segmentLengthForShortHatches(stepPixels);
      final double segmentPeriodPixels = segmentLengthPixels * 2.0;

      double firstSegmentStart =
          horizontalStart - (horizontalStart % segmentPeriodPixels);
      if (firstSegmentStart > horizontalStart) {
        firstSegmentStart -= segmentPeriodPixels;
      }

      for (double segmentStart = firstSegmentStart;
          segmentStart < horizontalEnd + segmentLengthPixels;
          segmentStart += segmentPeriodPixels) {
        final double segmentEffectiveStart =
            math.max(segmentStart, horizontalStart);
        final double segmentEffectiveEnd =
            math.min(segmentStart + segmentLengthPixels, horizontalEnd);
        if (segmentEffectiveEnd <= segmentEffectiveStart) continue;

        canvas.drawLine(
          Offset(segmentEffectiveStart, snappedY),
          Offset(segmentEffectiveEnd, snappedY),
          strokePaint,
        );
      }
    }

    canvas.restore();
  }

  bool _shouldUseShortSegments(StrokeLayerSpec layerSpec, double stepPixels) {
    final bool isHorizontalLayer = layerSpec.angleDeg % 180.0 == 0.0;
    final bool isRareSpacing = stepPixels >= 6.0 * pixelsPerMillimeter;
    final bool isThinStroke =
        (layerSpec.thicknessMm * pixelsPerMillimeter) <=
            0.25 * pixelsPerMillimeter;
    return isHorizontalLayer && isRareSpacing && isThinStroke;
  }

  double _segmentLengthForShortHatches(double stepPixels) {
    final double maxVisualSegment = 8.0 * pixelsPerMillimeter;
    final double byStep = stepPixels * 0.45;
    return math.max(3.0, math.min(maxVisualSegment, byStep));
  }

  Rect _rotatedAxisAlignedBounds(Rect rect, double angleRadians) {
    final List<Offset> corners = <Offset>[
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];
    final double cosine = math.cos(-angleRadians);
    final double sine = math.sin(-angleRadians);
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    for (final Offset corner in corners) {
      final double rotatedX = corner.dx * cosine - corner.dy * sine;
      final double rotatedY = corner.dx * sine + corner.dy * cosine;
      if (rotatedX < minX) minX = rotatedX;
      if (rotatedY < minY) minY = rotatedY;
      if (rotatedX > maxX) maxX = rotatedX;
      if (rotatedY > maxY) maxY = rotatedY;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
