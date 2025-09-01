import 'package:flutter/material.dart';
import '../domain/models.dart';
import 'patterns.dart';

const double maxLeaderLabelWidthMm = 80.0;
const double maxLegendTextWidthMm = 60.0;
const double depthFontSizeMm = 3.0;
const double thinLayerLimitMm = 5.0;
const double leaderShelfLenMm = 6.0;

double _snapStrokeCoord(double coord, double strokeWidth) {
  final int px = strokeWidth.round();
  final bool odd = (px % 2) == 1;
  return odd ? (coord.floorToDouble() + 0.5) : coord.roundToDouble();
}

class StratColumnPainter extends CustomPainter {
  final StratColumn column;
  final GostSet gostSet;
  final RenderSpec renderSpec;

  StratColumnPainter({
    required this.column,
    required this.gostSet,
    required this.renderSpec,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double previewZoom = renderSpec.previewZoom;
    if (previewZoom != 1.0) {
      canvas.save();
      canvas.scale(previewZoom);
      _paintCore(
        canvas,
        Size(size.width / previewZoom, size.height / previewZoom),
      );
      canvas.restore();
    } else {
      _paintCore(canvas, size);
    }
  }

  void _paintCore(Canvas canvas, Size size) {
    final double ppm = renderSpec.pixelsPerMillimeter;
    final PatternRenderer patternRenderer =
        PatternRenderer(pixelsPerMillimeter: ppm);

    const double leftScaleWidthMm = 30.0;
    final double leftScaleWidthPx = leftScaleWidthMm * ppm;
    final double columnWidthPx = renderSpec.columnWidthMm * ppm;
    final double bodyLeftPx = leftScaleWidthPx + 8.0;
    final Rect bodyRect =
        Rect.fromLTWH(bodyLeftPx, 16.0, columnWidthPx, size.height - 32.0);

    double maxDepthMeters = 0.0;
    for (final StratInterval interval in column.intervals) {
      if (interval.endDepthMeters > maxDepthMeters) {
        maxDepthMeters = interval.endDepthMeters;
      }
    }

    if (renderSpec.showDepthGrid) {
      _drawDepthScale(
        canvas: canvas,
        canvasSize: size,
        pixelsPerMillimeter: ppm,
        leftScaleX: leftScaleWidthPx,
        bodyTop: bodyRect.top,
        bodyHeight: bodyRect.height,
        maxDepthMeters: maxDepthMeters,
      );
    }

    for (final StratInterval interval in column.intervals) {
      final double topY =
          bodyRect.top + interval.startDepthMeters * renderSpec.scaleMmPerMeter * ppm;
      final double bottomY =
          bodyRect.top + interval.endDepthMeters * renderSpec.scaleMmPerMeter * ppm;
      final Rect intervalRect =
          Rect.fromLTRB(bodyRect.left, topY, bodyRect.right, bottomY);

      final String canonicalLithologyKey =
          _canonicalLithology(interval.lithologyRaw);

      final Color? backgroundColor =
          gostSet.defaultColors[canonicalLithologyKey];
      if (backgroundColor != null) {
        final Paint fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = backgroundColor.withOpacity(0.45)
          ..isAntiAlias = false;
        canvas.drawRect(intervalRect, fillPaint);
      }

      final List<CompositionPart> compositionParts =
          _effectiveComposition(interval, canonicalLithologyKey);
      _drawComposition(canvas, intervalRect, compositionParts, patternRenderer);

      final Paint borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.3 * ppm
        ..color = Colors.black
        ..isAntiAlias = false;

      final double half = borderPaint.strokeWidth / 2.0;
      final Rect snapped = Rect.fromLTRB(
        _snapStrokeCoord(intervalRect.left + half, borderPaint.strokeWidth) - half,
        _snapStrokeCoord(intervalRect.top + half, borderPaint.strokeWidth) - half,
        _snapStrokeCoord(intervalRect.right - half, borderPaint.strokeWidth) + half,
        _snapStrokeCoord(intervalRect.bottom - half, borderPaint.strokeWidth) + half,
      );
      canvas.drawRect(snapped, borderPaint);

      if (renderSpec.showIntervalLabels) {
        _drawIntervalLabel(
          canvas,
          intervalRect,
          canonicalLithologyKey,
          interval,
        );
      }
    }

    if (renderSpec.showLegend) {
      _drawLegend(canvas, size, patternRenderer, bodyRect);
    }
  }

  String _canonicalLithology(String rawLithology) {
    final String normalizedKey = rawLithology.trim().toLowerCase();
    if (gostSet.mapping.containsKey(normalizedKey)) return normalizedKey;
    if (gostSet.synonyms.containsKey(normalizedKey)) {
      return gostSet.synonyms[normalizedKey]!;
    }
    return normalizedKey;
  }

  List<CompositionPart> _effectiveComposition(
    StratInterval interval,
    String canonicalMain,
  ) {
    if (interval.compositionParts != null &&
        interval.compositionParts!.isNotEmpty) {
      return interval.compositionParts!;
    }
    return [CompositionPart(lithologyKey: canonicalMain, percent: 100.0)];
  }

  void _drawComposition(
    Canvas canvas,
    Rect rect,
    List<CompositionPart> parts,
    PatternRenderer renderer,
  ) {
    const double minStripeWidthMm = 1.2;
    final double minStripeWidthPx = minStripeWidthMm * renderSpec.pixelsPerMillimeter;

    final double totalPercent =
        parts.fold(0.0, (sum, part) => sum + part.percent);
    double currentX = rect.left;

    for (int partIndex = 0; partIndex < parts.length; partIndex++) {
      if (currentX >= rect.right - 0.5) break;

      final CompositionPart part = parts[partIndex];
      final double partFraction =
          (totalPercent > 0.0) ? (part.percent / totalPercent) : (1.0 / parts.length);

      double desiredWidthPx = rect.width * partFraction;
      if (desiredWidthPx < minStripeWidthPx) desiredWidthPx = minStripeWidthPx;

      final bool isLastStripe = (partIndex == parts.length - 1);
      final double stripeRight =
          isLastStripe ? rect.right : (currentX + desiredWidthPx).clamp(currentX, rect.right);

      if (stripeRight - currentX <= 0.5) break;

      final Rect stripeRect =
          Rect.fromLTRB(currentX, rect.top, stripeRight, rect.bottom);
      final String stripeLithologyKey =
          _canonicalLithology(part.lithologyKey);

      final String? patternId = gostSet.mapping[stripeLithologyKey];
      final GostPatternSpec? patternSpec =
          (patternId != null) ? gostSet.patterns[patternId] : null;

      final GostPatternSpec safePatternSpec = patternSpec ??
          const GostPatternSpec(
            id: '_fallback',
            descriptionRu: 'fallback',
            layers: [
              StrokeLayerSpec(angleDeg: 45, stepMm: 2.0, thicknessMm: 0.2),
              StrokeLayerSpec(angleDeg: 135, stepMm: 2.0, thicknessMm: 0.2),
            ],
          );

      renderer.drawPattern(
        canvas,
        stripeRect,
        safePatternSpec,
        colorHint: Colors.black,
      );

      currentX = stripeRight;
    }
  }

  void _drawDepthScale({
    required Canvas canvas,
    required Size canvasSize,
    required double pixelsPerMillimeter,
    required double leftScaleX,
    required double bodyTop,
    required double bodyHeight,
    required double maxDepthMeters,
  }) {
    final double mpm = renderSpec.scaleMmPerMeter;
    final double desiredBottom = bodyTop + maxDepthMeters * mpm * pixelsPerMillimeter;

    final Paint axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4 * pixelsPerMillimeter
      ..color = Colors.black
      ..isAntiAlias = false;

    final double x = _snapStrokeCoord(leftScaleX - 8.0, axisPaint.strokeWidth);
    final double yTop = bodyTop;
    final double yBottom = desiredBottom;

    canvas.drawLine(Offset(x, yTop), Offset(x, yBottom), axisPaint);

    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    final double majorStep = gostSet.tickMajorMeters;
    final double minorStep = gostSet.tickMinorMeters;

    for (double meterValue = 0.0;
        meterValue <= maxDepthMeters + 1e-9;
        meterValue += minorStep) {
      final double tickY =
          bodyTop + meterValue * mpm * pixelsPerMillimeter;
      final double snappedTickY =
          _snapStrokeCoord(tickY, axisPaint.strokeWidth);
      final bool isMajor = (meterValue % majorStep).abs() < 1e-6;
      final double tickLength = isMajor ? 6.0 : 3.0;

      canvas.drawLine(
        Offset(x, snappedTickY),
        Offset(x - tickLength, snappedTickY),
        axisPaint,
      );

      if (isMajor) {
        textPainter.text = TextSpan(
          style: TextStyle(
            color: Colors.black,
            fontSize: depthFontSizeMm * pixelsPerMillimeter,
            fontFamily: renderSpec.fontFamily,
          ),
          text: meterValue.toStringAsFixed(0),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            x - 8.0 - textPainter.width,
            snappedTickY - textPainter.height / 2,
          ),
        );
      }
    }
  }

  void _drawIntervalLabel(
    Canvas canvas,
    Rect intervalRect,
    String canonicalLithologyKey,
    StratInterval interval,
  ) {
    final double ppm = renderSpec.pixelsPerMillimeter;

    final double fontSizePixels = depthFontSizeMm * ppm;
    final double thinThresholdPixels = thinLayerLimitMm * ppm;
    final double leaderShelfPixels = leaderShelfLenMm * ppm;

    final String rangeText =
        '${interval.startDepthMeters.toStringAsFixed(2)}–${interval.endDepthMeters.toStringAsFixed(2)} м';
    final String noteText =
        (interval.note != null && interval.note!.isNotEmpty) ? ' — ${interval.note!}' : '';
    final String fullText = '$canonicalLithologyKey | $rangeText$noteText';

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
      text: TextSpan(
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSizePixels,
          fontFamily: renderSpec.fontFamily,
        ),
        text: fullText,
      ),
    );

    if (intervalRect.height < thinThresholdPixels) {
      final double centerY = intervalRect.center.dy;

      final Paint leaderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.2 * ppm
        ..color = Colors.black
        ..isAntiAlias = false;

      final double y = _snapStrokeCoord(centerY, leaderPaint.strokeWidth);
      canvas.drawLine(
        Offset(intervalRect.right, y),
        Offset(intervalRect.right + leaderShelfPixels, y),
        leaderPaint,
      );

      textPainter.layout(maxWidth: maxLeaderLabelWidthMm * ppm);
      textPainter.paint(
        canvas,
        Offset(
          intervalRect.right + leaderShelfPixels + 4.0,
          y - textPainter.height / 2,
        ),
      );
    } else {
      textPainter.layout(maxWidth: intervalRect.width - 6.0);
      canvas.save();
      canvas.clipRect(intervalRect.deflate(2.0));
      textPainter.paint(
        canvas,
        Offset(
          intervalRect.left + 3.0,
          intervalRect.center.dy - textPainter.height / 2,
        ),
      );
      canvas.restore();
    }
  }

  void _drawLegend(
    Canvas canvas,
    Size canvasSize,
    PatternRenderer renderer,
    Rect bodyRect,
  ) {
    final double ppm = renderSpec.pixelsPerMillimeter;

    final double leadersRight = _computeLeadersRightPx(bodyRect);
    final double legendLeft =
        ((leadersRight > bodyRect.right) ? leadersRight : bodyRect.right) + 12.0;

    final double sampleWidth = gostSet.legendSampleWidthMm * ppm;
    final double sampleHeight = gostSet.legendSampleHeightMm * ppm;

    final Set<String> usedLithologies = <String>{};
    for (final StratInterval interval in column.intervals) {
      usedLithologies.add(_canonicalLithology(interval.lithologyRaw));
      if (interval.compositionParts != null) {
        for (final CompositionPart part in interval.compositionParts!) {
          usedLithologies.add(_canonicalLithology(part.lithologyKey));
        }
      }
    }

    final List<String> legendOrder = <String>[];
    for (final String lith in gostSet.legendOrder) {
      if (usedLithologies.contains(lith)) legendOrder.add(lith);
    }
    for (final String lith in usedLithologies) {
      if (!legendOrder.contains(lith)) legendOrder.add(lith);
    }

    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

    double currentY = bodyRect.top;
    for (final String lithologyKey in legendOrder) {
      final String? patternId = gostSet.mapping[lithologyKey];
      if (patternId == null) continue;
      final GostPatternSpec patternSpec = gostSet.patterns[patternId]!;
      final Rect sampleRect =
          Rect.fromLTWH(legendLeft, currentY, sampleWidth, sampleHeight);

      final Paint fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color =
            (gostSet.defaultColors[lithologyKey] ?? const Color(0xFFEFEFEF))
                .withOpacity(0.6)
        ..isAntiAlias = false;
      canvas.drawRect(sampleRect, fillPaint);

      renderer.drawPattern(
        canvas,
        sampleRect,
        patternSpec,
        colorHint: Colors.black,
      );

      final Paint borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.3 * ppm
        ..color = Colors.black
        ..isAntiAlias = false;

      final double half = borderPaint.strokeWidth / 2.0;
      final Rect snapped = Rect.fromLTRB(
        _snapStrokeCoord(sampleRect.left + half, borderPaint.strokeWidth) - half,
        _snapStrokeCoord(sampleRect.top + half, borderPaint.strokeWidth) - half,
        _snapStrokeCoord(sampleRect.right - half, borderPaint.strokeWidth) + half,
        _snapStrokeCoord(sampleRect.bottom - half, borderPaint.strokeWidth) + half,
      );
      canvas.drawRect(snapped, borderPaint);

      textPainter.text = TextSpan(
        style: TextStyle(
          color: Colors.black,
          fontSize: 12.0,
          fontFamily: renderSpec.fontFamily,
        ),
        text: lithologyKey,
      );
      textPainter.layout(maxWidth: maxLegendTextWidthMm * ppm);
      textPainter.paint(
        canvas,
        Offset(
          sampleRect.right + 8.0,
          sampleRect.top + (sampleHeight - textPainter.height) / 2,
        ),
      );

      currentY += sampleHeight + 8.0;
    }
  }

  @override
  bool shouldRepaint(covariant StratColumnPainter oldDelegate) {
    return column != oldDelegate.column ||
        gostSet != oldDelegate.gostSet ||
        renderSpec != oldDelegate.renderSpec;
  }

  double _computeLeadersRightPx(Rect bodyRect) {
    final double ppm = renderSpec.pixelsPerMillimeter;
    final double leaderShelfPixels = leaderShelfLenMm * ppm;
    final double thinThresholdPixels = thinLayerLimitMm * ppm;
    final double mpm = renderSpec.scaleMmPerMeter;

    double rightmost = bodyRect.right;
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final StratInterval interval in column.intervals) {
      final double topY = bodyRect.top + interval.startDepthMeters * mpm * ppm;
      final double bottomY = bodyRect.top + interval.endDepthMeters * mpm * ppm;

      if ((bottomY - topY).abs() < thinThresholdPixels) {
        final String lithologyKey = _canonicalLithology(interval.lithologyRaw);
        final String range =
            '${interval.startDepthMeters.toStringAsFixed(2)}–${interval.endDepthMeters.toStringAsFixed(2)} м';
        final String note =
            (interval.note != null && interval.note!.isNotEmpty) ? ' — ${interval.note!}' : '';
        final String label = '$lithologyKey | $range$note';

        textPainter.text = TextSpan(
          style: TextStyle(
            color: Colors.black,
            fontSize: depthFontSizeMm * ppm,
            fontFamily: renderSpec.fontFamily,
          ),
          text: label,
        );
        textPainter.layout(maxWidth: maxLeaderLabelWidthMm * ppm);

        final double candidateRight =
            bodyRect.right + leaderShelfPixels + 4.0 + textPainter.width;
        if (candidateRight > rightmost) rightmost = candidateRight;
      }
    }
    return rightmost;
  }
}
