import 'dart:convert' show HtmlEscape;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../rendering/column_painter.dart';

const double _maxLeaderLabelWidthMm = 80.0;
const double _maxLegendTextWidthMm = 60.0;

class ExportOptions {
  final double paddingMm;
  final double pngPixelRatio;
  final bool includeFooter;
  final bool transparentBackground;

  const ExportOptions({
    required this.paddingMm,
    required this.pngPixelRatio,
    required this.includeFooter,
    required this.transparentBackground,
  });

  ExportOptions copyWith({
    double? paddingMm,
    double? pngPixelRatio,
    bool? includeFooter,
    bool? transparentBackground,
  }) {
    return ExportOptions(
      paddingMm: paddingMm ?? this.paddingMm,
      pngPixelRatio: pngPixelRatio ?? this.pngPixelRatio,
      includeFooter: includeFooter ?? this.includeFooter,
      transparentBackground: transparentBackground ?? this.transparentBackground,
    );
  }
}

class ExportService {
  static Rect computeSceneBounds(
    StratColumn column,
    GostSet gost,
    RenderSpec spec, {
    bool includeFooter = false,
  }) {
    final double px = spec.pixelsPerMillimeter;

    const double leftScaleWidthMm = 30.0;
    final double leftScaleWidthPx = leftScaleWidthMm * px;
    final double columnWidthPx = spec.columnWidthMm * px;
    final double bodyLeftPx = leftScaleWidthPx + 8.0;

    double maxDepthMeters = 0.0;
    for (final StratInterval it in column.intervals) {
      if (it.endDepthMeters > maxDepthMeters) maxDepthMeters = it.endDepthMeters;
    }

    const double topY = 16.0;
    final double bodyHeightPx = maxDepthMeters * spec.scaleMmPerMeter * px;
    double sceneBottom = topY + bodyHeightPx;

    final TextPainter depthPainter = TextPainter(textDirection: TextDirection.ltr);
    depthPainter.text = TextSpan(
      text: '${maxDepthMeters.floor()} м',
      style: TextStyle(
        color: Colors.black,
        fontSize: 3.0 * px,
        fontFamily: spec.fontFamily,
      ),
    );
    depthPainter.layout(maxWidth: 40.0 * px);
    const double axisOffset = 8.0, majorTick = 6.0, textGap = 8.0;
    final double minLeftX =
        (leftScaleWidthPx - axisOffset) - majorTick - textGap - depthPainter.width;

    final double bodyRight = bodyLeftPx + columnWidthPx;
    double rightmostX = bodyRight;

    if (spec.showIntervalLabels) {
      final double minH = 5.0 * px;
      final double leaderShelf = 6.0 * px;
      final TextPainter tp = TextPainter(textDirection: TextDirection.ltr);
      final double maxLeaderW = _maxLeaderLabelWidthMm * px;

      for (final StratInterval it in column.intervals) {
        final double y1 = topY + it.startDepthMeters * spec.scaleMmPerMeter * px;
        final double y2 = topY + it.endDepthMeters * spec.scaleMmPerMeter * px;
        final double yc = (y1 + y2) / 2.0;
        if ((y2 - y1).abs() < minH) {
          final String lith = _canon(gost, it.lithologyRaw);
          final String range =
              '${it.startDepthMeters.toStringAsFixed(2)}–${it.endDepthMeters.toStringAsFixed(2)} м';
          final String note =
              (it.note != null && it.note!.isNotEmpty) ? ' — ${it.note!}' : '';
          final String label = '$lith | $range$note';
          tp.text = TextSpan(
            style: TextStyle(color: Colors.black, fontSize: 3.0 * px, fontFamily: spec.fontFamily),
            text: label,
          );
          tp.layout(maxWidth: maxLeaderW);
          final double candidate = bodyRight + leaderShelf + 4.0 + tp.width;
          if (candidate > rightmostX) rightmostX = candidate;
          final double low = yc + tp.height / 2 + 2.0;
          if (low > sceneBottom) sceneBottom = low;
        }
      }
    }

    if (spec.showLegend) {
      final Set<String> used = <String>{};
      for (final StratInterval it in column.intervals) {
        used.add(_canon(gost, it.lithologyRaw));
        final parts = it.compositionParts;
        if (parts != null) {
          for (final p in parts) used.add(_canon(gost, p.lithologyKey));
        }
      }
      final List<String> legendOrder = <String>[];
      for (final s in gost.legendOrder) {
        if (used.contains(s)) legendOrder.add(s);
      }
      for (final s in used) {
        if (!legendOrder.contains(s)) legendOrder.add(s);
      }

      final double sampleW = gost.legendSampleWidthMm * px;
      final double sampleH = gost.legendSampleHeightMm * px;

      final double legendX =
          rightmostX > bodyRight ? rightmostX + 12.0 : bodyRight + 12.0;

      final TextPainter tp = TextPainter(textDirection: TextDirection.ltr);
      final double maxLegendTextW = _maxLegendTextWidthMm * px;
      double maxText = 0.0;
      for (final lith in legendOrder) {
        tp.text = TextSpan(
          style: TextStyle(color: Colors.black, fontSize: 12.0, fontFamily: spec.fontFamily),
          text: lith,
        );
        tp.layout(maxWidth: maxLegendTextW);
        if (tp.width > maxText) maxText = tp.width;
      }
      final double legendRight = legendX + sampleW + 8.0 + maxText;
      if (legendRight > rightmostX) rightmostX = legendRight;

      final double legendBottom =
          topY + legendOrder.length * (sampleH + 8.0) - 8.0;
      if (legendBottom > sceneBottom) sceneBottom = legendBottom;
    }

    if (includeFooter) {
      final TextPainter ft = TextPainter(textDirection: TextDirection.ltr);
      ft.text = TextSpan(
        style: TextStyle(color: Colors.black, fontSize: 3.0 * px, fontFamily: spec.fontFamily),
        text:
            'Масштаб: ${spec.scaleMmPerMeter.toStringAsFixed(1)} мм = 1 м  •  ГОСТ 21.302-2013',
      );
      ft.layout(maxWidth: 2400);
      sceneBottom += 8.0 + ft.height;
    }

    final double strokeHalf = 0.8 * px;
    return Rect.fromLTRB(
      minLeftX - strokeHalf,
      topY - strokeHalf,
      rightmostX + strokeHalf,
      sceneBottom + strokeHalf,
    );
  }

  static Future<Uint8List> renderPngTight(
    StratColumn column,
    GostSet gost,
    RenderSpec spec, {
    required ExportOptions options,
  }) async {
    final double pxPerMm = spec.pixelsPerMillimeter;
    final double pr = options.pngPixelRatio.clamp(1.0, 10.0);

    final Rect bounds =
        computeSceneBounds(column, gost, spec, includeFooter: options.includeFooter);
    final double logicalW = bounds.width;
    final double logicalH = bounds.height;

    final int bigW = (logicalW * pr).round();
    final int bigH = (logicalH * pr).round();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas =
        Canvas(recorder, Rect.fromLTWH(0, 0, bigW.toDouble(), bigH.toDouble()));

    canvas.scale(pr);
    canvas.translate(-bounds.left, -bounds.top);

    final StratColumnPainter painter = StratColumnPainter(
      column: column,
      gostSet: gost,
      renderSpec: spec.copyWith(previewZoom: 1.0),
    );
    painter.paint(canvas, Size(logicalW, logicalH));

    final ui.Image bigImage = await recorder.endRecording().toImage(bigW, bigH);

    final ByteData? raw =
        await bigImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (raw == null) {
      final ByteData? fallback =
          await bigImage.toByteData(format: ui.ImageByteFormat.png);
      return fallback!.buffer.asUint8List();
    }
    final Uint8List buf = raw.buffer.asUint8List();

    int minX = bigW, minY = bigH, maxX = -1, maxY = -1;
    int i = 0;
    for (int y = 0; y < bigH; y++) {
      for (int x = 0; x < bigW; x++) {
        final int a = buf[i + 3];
        if (a != 0) {
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
        i += 4;
      }
    }

    if (maxX < 0 || maxY < 0) {
      final ByteData? empty =
          await bigImage.toByteData(format: ui.ImageByteFormat.png);
      return empty!.buffer.asUint8List();
    }

    final double strokePx = (0.35 * pxPerMm) * pr;
    final int safety = math.max(strokePx.ceil(), 3);
    final int padPx = (options.paddingMm * pxPerMm * pr).round();

    minX = (minX - safety - padPx).clamp(0, bigW - 1);
    minY = (minY - safety - padPx).clamp(0, bigH - 1);
    maxX = (maxX + safety + padPx).clamp(0, bigW - 1);
    maxY = (maxY + safety + padPx).clamp(0, bigH - 1);

    final int cropW = maxX - minX + 1;
    final int cropH = maxY - minY + 1;

    final ui.PictureRecorder outRec = ui.PictureRecorder();
    final Canvas outCanvas =
        Canvas(outRec, Rect.fromLTWH(0, 0, cropW.toDouble(), cropH.toDouble()));

    if (!options.transparentBackground) {
      outCanvas.drawRect(
        Rect.fromLTWH(0, 0, cropW.toDouble(), cropH.toDouble()),
        Paint()..color = Colors.white,
      );
    }

    final Rect src =
        Rect.fromLTWH(minX.toDouble(), minY.toDouble(), cropW.toDouble(), cropH.toDouble());
    final Rect dst = Rect.fromLTWH(0, 0, cropW.toDouble(), cropH.toDouble());
    outCanvas.drawImageRect(
      bigImage,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );

    final ui.Image outImg = await outRec.endRecording().toImage(cropW, cropH);
    final ByteData? png = await outImg.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  }

  static String buildSvgTight(
    StratColumn column,
    GostSet gost,
    RenderSpec spec, {
    required ExportOptions options,
  }) {
    final double px = spec.pixelsPerMillimeter;
    final double padPx = (options.paddingMm) * px;

    final Rect bounds =
        computeSceneBounds(column, gost, spec, includeFooter: options.includeFooter);
    final double w = bounds.width + 2 * padPx;
    final double h = bounds.height + 2 * padPx;

    String esc(String s) => const HtmlEscape().convert(s);
    String hex(Color c) => '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';

    final Set<String> usedPatternIds = <String>{};
    void _collectForLith(String lith) {
      final String canon = _canon(gost, lith);
      final String? patId = gost.mapping[canon];
      if (patId != null && gost.patterns.containsKey(patId)) {
        usedPatternIds.add(patId);
      }
    }

    for (final StratInterval it in column.intervals) {
      _collectForLith(it.lithologyRaw);
      if (it.compositionParts != null) {
        for (final CompositionPart p in it.compositionParts!) {
          _collectForLith(p.lithologyKey);
        }
      }
    }
    for (final String k in gost.legendOrder) {
      _collectForLith(k);
    }

    final StringBuffer defs = StringBuffer();
    for (final String patId in usedPatternIds) {
      final GostPatternSpec ps = gost.patterns[patId]!;
      for (int i = 0; i < ps.layers.length; i++) {
        defs.writeln(_svgPatternLayer(ps.layers[i], px, 'pat_${patId}_L$i'));
      }
    }

    final StringBuffer out = StringBuffer();
    out.writeln('<svg xmlns="http://www.w3.org/2000/svg" version="1.1" '
        'width="${w.toStringAsFixed(0)}" height="${h.toStringAsFixed(0)}" '
        'viewBox="0 0 ${w.toStringAsFixed(0)} ${h.toStringAsFixed(0)}">');

    if (!options.transparentBackground) {
      out.writeln('<rect x="0" y="0" width="$w" height="$h" fill="#FFFFFF"/>');
    }

    out.writeln('<defs>${defs.toString()}</defs>');

    out.writeln('<g transform="translate(${(padPx - bounds.left).toStringAsFixed(2)}, '
        '${(padPx - bounds.top).toStringAsFixed(2)})">');

    _emitDepthAxisSvg(out, column, gost, spec);

    const double leftScaleWidthMm = 30.0;
    final double leftScalePx = leftScaleWidthMm * px;
    final double bodyWidthPx = spec.columnWidthMm * px;
    final double bodyLeftPx = leftScalePx + 8.0;

    double maxDepthMeters = 0.0;
    for (final StratInterval it in column.intervals) {
      if (it.endDepthMeters > maxDepthMeters) maxDepthMeters = it.endDepthMeters;
    }

    final double topY = 16.0;
    final double mmPerM = spec.scaleMmPerMeter;
    final Rect bodyRect = Rect.fromLTWH(
      bodyLeftPx,
      topY,
      bodyWidthPx,
      maxDepthMeters * mmPerM * px,
    );

    for (final StratInterval it in column.intervals) {
      final double yTop = bodyRect.top + it.startDepthMeters * mmPerM * px;
      final double yBot = bodyRect.top + it.endDepthMeters * mmPerM * px;
      final Rect r = Rect.fromLTRB(bodyRect.left, yTop, bodyRect.right, yBot);

      final String canon = _canon(gost, it.lithologyRaw);
      final Color? bg = gost.defaultColors[canon];

      if (bg != null) {
        out.writeln('<rect x="${r.left}" y="${r.top}" width="${r.width}" height="${r.height}" '
            'fill="${hex(bg)}" fill-opacity="0.45"/>');
      }

      final String? patId = gost.mapping[canon];
      if (patId != null && gost.patterns.containsKey(patId)) {
        final GostPatternSpec ps = gost.patterns[patId]!;
        for (int i = 0; i < ps.layers.length; i++) {
          out.writeln('<rect x="${r.left}" y="${r.top}" width="${r.width}" height="${r.height}" '
              'fill="url(#pat_${patId}_L$i)"/>');
        }
      }

      out.writeln('<rect x="${r.left}" y="${r.top}" width="${r.width}" height="${r.height}" '
          'fill="none" stroke="#000" stroke-width="${(0.3 * px).toStringAsFixed(3)}" '
          'vector-effect="non-scaling-stroke" shape-rendering="crispEdges" '
          'shape-rendering="crispEdges"/>');

      if (spec.showIntervalLabels) {
        final double fontPx = 3.0 * px;
        final double thinH = 5.0 * px;
        final String range =
            '${it.startDepthMeters.toStringAsFixed(2)}–${it.endDepthMeters.toStringAsFixed(2)} м';
        final String note =
            (it.note != null && it.note!.isNotEmpty) ? ' — ${esc(it.note!)}' : '';
        final String label = '${esc(canon)} | $range$note';

        if (r.height < thinH) {
          final double y = (r.top + r.bottom) / 2;
          final double p0x = r.right, p1x = r.right + 6.0 * px;
          out.writeln('<line x1="$p0x" y1="$y" x2="$p1x" y2="$y" '
              'stroke="#000" stroke-width="${(0.2 * px).toStringAsFixed(3)}" '
              'vector-effect="non-scaling-stroke" shape-rendering="crispEdges" '
              'stroke-linecap="butt" stroke-linejoin="miter"/>');
          out.writeln('<text x="${p1x + 4.0}" y="${y + 1.2 * px}" '
              'font-family="${spec.fontFamily},sans-serif" font-size="${(fontPx).toStringAsFixed(3)}" '
              'fill="#000">$label</text>');
        } else {
          final double tx = r.left + 3.0;
          final double ty = r.center.dy + 0.5 * fontPx;
          out.writeln('<text x="$tx" y="$ty" font-family="${spec.fontFamily},sans-serif" '
              'font-size="${(fontPx).toStringAsFixed(3)}" fill="#000">$label</text>');
        }
      }
    }

    if (spec.showLegend) {
      final Set<String> used = <String>{};
      for (final StratInterval it in column.intervals) {
        used.add(_canon(gost, it.lithologyRaw));
        final parts = it.compositionParts;
        if (parts != null) {
          for (final p in parts) used.add(_canon(gost, p.lithologyKey));
        }
      }
      final List<String> legend = <String>[];
      for (final s in gost.legendOrder) {
        if (used.contains(s)) legend.add(s);
      }
      for (final s in used) {
        if (!legend.contains(s)) legend.add(s);
      }

      double y = bodyRect.top;
      final double sampleW = gost.legendSampleWidthMm * px;
      final double sampleH = gost.legendSampleHeightMm * px;
      final double legendX = bodyRect.right + 12.0;

      for (final String canon in legend) {
        final Rect s = Rect.fromLTWH(legendX, y, sampleW, sampleH);
        final Color bg = gost.defaultColors[canon] ?? const Color(0xFFEFEFEF);

        out.writeln('<rect x="${s.left}" y="${s.top}" width="${s.width}" height="${s.height}" '
            'fill="${hex(bg)}" fill-opacity="0.6"/>');

        final String? patId = gost.mapping[canon];
        if (patId != null && gost.patterns.containsKey(patId)) {
          final GostPatternSpec ps = gost.patterns[patId]!;
          for (int i = 0; i < ps.layers.length; i++) {
            out.writeln('<rect x="${s.left}" y="${s.top}" width="${s.width}" height="${s.height}" '
                'fill="url(#pat_${patId}_L$i)"/>');
          }
        }

        out.writeln('<rect x="${s.left}" y="${s.top}" width="${s.width}" height="${s.height}" '
            'fill="none" stroke="#000" stroke-width="${(0.3 * px).toStringAsFixed(3)}" '
            'vector-effect="non-scaling-stroke" shape-rendering="crispEdges"/>');

        out.writeln('<text x="${s.right + 8.0}" y="${s.top + (sampleH - 12) / 2 + 10}" '
            'font-family="${spec.fontFamily},sans-serif" font-size="12" '
            'fill="#000">${esc(canon)}</text>');

        y += sampleH + 8.0;
      }
    }

    out.writeln('</g></svg>');
    return out.toString();
  }

  static String _canon(GostSet set, String raw) {
    final String k = raw.trim().toLowerCase();
    if (set.mapping.containsKey(k)) return k;
    if (set.synonyms.containsKey(k)) return set.synonyms[k]!;
    const Map<String, String> b = {
      'sand': 'песок',
      'clay': 'глина',
      'loam': 'суглинок',
      'silt': 'алевролит',
      'siltstone': 'алевролит',
      'limestone': 'известняк',
      'sandstone': 'песчаник',
      'gravel': 'гравий',
      'pebble': 'галька',
      'pebbles': 'галька',
      'dolomite': 'доломит',
      'marl': 'мергель',
    };
    return b[k] ?? k;
  }

  static void _emitDepthAxisSvg(
    StringBuffer out,
    StratColumn column,
    GostSet gost,
    RenderSpec spec,
  ) {
    final double px = spec.pixelsPerMillimeter;

    const double leftScaleWidthMm = 30.0;
    final double leftScalePx = leftScaleWidthMm * px;

    double maxDepthMeters = 0.0;
    for (final StratInterval it in column.intervals) {
      if (it.endDepthMeters > maxDepthMeters) maxDepthMeters = it.endDepthMeters;
    }

    final double topY = 16.0;
    final double mmPerM = spec.scaleMmPerMeter;
    final double bodyTop = topY;
    final double bodyBottom = bodyTop + maxDepthMeters * mmPerM * px;

    out.writeln('<line x1="${leftScalePx - 8.0}" y1="$bodyTop" '
        'x2="${leftScalePx - 8.0}" y2="$bodyBottom" '
        'stroke="#000" stroke-width="${(0.4 * px).toStringAsFixed(3)}" '
        'vector-effect="non-scaling-stroke" shape-rendering="crispEdges" '
        'stroke-linecap="butt" stroke-linejoin="miter"/>');

    final double major = gost.tickMajorMeters, minor = gost.tickMinorMeters;
    for (double m = 0.0; m <= maxDepthMeters + 1e-6; m += minor) {
      final double y = bodyTop + m * mmPerM * px;
      final bool isMajor = (m % major).abs() < 1e-6;
      final double tick = isMajor ? 6.0 : 3.0;
      out.writeln('<line x1="${leftScalePx - 8.0}" y1="$y" '
          'x2="${leftScalePx - 8.0 - tick}" y2="$y" '
          'stroke="#000" stroke-width="${(0.4 * px).toStringAsFixed(3)}" '
          'vector-effect="non-scaling-stroke" shape-rendering="crispEdges" '
          'stroke-linecap="butt" stroke-linejoin="miter"/>');
      if (isMajor) {
        out.writeln('<text x="${leftScalePx - 8.0 - 8.0 - 18.0}" y="${y + 1.2 * px}" '
            'font-family="${spec.fontFamily},sans-serif" font-size="${(3.0 * px).toStringAsFixed(3)}" '
            'fill="#000">${m.toStringAsFixed(0)} м</text>');
      }
    }
  }

  static String _svgPatternLayer(StrokeLayerSpec layer, double pxPerMm, String id) {
    final double stepPx = (layer.stepMm * pxPerMm).clamp(0.5, 800.0);
    final double strokePx = (layer.thicknessMm * pxPerMm).clamp(0.1, 10.0);
    final String a = layer.angleDeg.toStringAsFixed(3);

    return '''
<pattern id="$id" patternUnits="userSpaceOnUse"
         width="${stepPx.toStringAsFixed(3)}" height="${stepPx.toStringAsFixed(3)}"
         patternTransform="rotate($a)">
  <line x1="0" y1="0" x2="${stepPx.toStringAsFixed(3)}" y2="0"
        stroke="#000" stroke-width="${strokePx.toStringAsFixed(3)}"
        vector-effect="non-scaling-stroke" shape-rendering="crispEdges"
        stroke-linecap="butt" stroke-linejoin="miter"/>
</pattern>
''';
  }
}