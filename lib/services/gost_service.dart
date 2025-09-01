import 'package:flutter/material.dart';
import 'package:toml/toml.dart' as toml;

import '../domain/models.dart';

class GostService {
  Future<GostSet> loadBuiltin() async {
    const ExportDefaults exportDefaults = ExportDefaults(
      paddingMm: 3.0,
      defaultDpi: 300,
      transparentBackground: false,
    );

    return GostSet(
      mapping: const {
        'песок': 'sand',
        'суглинок': 'loam',
        'глина': 'clay',
        'песчаник': 'sandstone',
        'известняк': 'limestone',
        'гравий': 'gravel',
        'галька': 'pebble',
        'мергель': 'marl',
        'алевролит': 'silt',
        'доломит': 'dolomite',
      },
      synonyms: const {
        'sand': 'песок',
        'loam': 'суглинок',
        'clay': 'глина',
        'sandstone': 'песчаник',
        'limestone': 'известняк',
        'gravel': 'гравий',
        'pebble': 'галька',
        'marl': 'мергель',
        'silt': 'алевролит',
        'siltstone': 'алевролит',
        'dolomite': 'доломит',
      },
      patterns: const {
        'sand': GostPatternSpec(
          id: 'sand',
          descriptionRu: 'Песок',
          layers: [StrokeLayerSpec(angleDeg: 90, stepMm: 1.8, thicknessMm: 0.20)],
        ),
        'loam': GostPatternSpec(
          id: 'loam',
          descriptionRu: 'Суглинок',
          layers: [
            StrokeLayerSpec(angleDeg: 90, stepMm: 2.4, thicknessMm: 0.18),
            StrokeLayerSpec(angleDeg: 90, stepMm: 2.4, thicknessMm: 0.45),
          ],
        ),
        'clay': GostPatternSpec(
          id: 'clay',
          descriptionRu: 'Глина',
          layers: [StrokeLayerSpec(angleDeg: 45, stepMm: 2.0, thicknessMm: 0.20)],
        ),
        'sandstone': GostPatternSpec(
          id: 'sandstone',
          descriptionRu: 'Песчаник',
          layers: [
            StrokeLayerSpec(angleDeg: 45, stepMm: 3.0, thicknessMm: 0.20),
            StrokeLayerSpec(angleDeg: 135, stepMm: 3.0, thicknessMm: 0.20),
          ],
        ),
        'limestone': GostPatternSpec(
          id: 'limestone',
          descriptionRu: 'Известняк',
          layers: [
            StrokeLayerSpec(angleDeg: 30, stepMm: 3.0, thicknessMm: 0.20),
            StrokeLayerSpec(angleDeg: 150, stepMm: 3.0, thicknessMm: 0.20),
          ],
        ),
        'gravel': GostPatternSpec(
          id: 'gravel',
          descriptionRu: 'Гравий',
          layers: [
            StrokeLayerSpec(angleDeg: 60, stepMm: 3.2, thicknessMm: 0.24),
            StrokeLayerSpec(angleDeg: 120, stepMm: 3.2, thicknessMm: 0.24),
          ],
        ),
        'pebble': GostPatternSpec(
          id: 'pebble',
          descriptionRu: 'Галька',
          layers: [
            StrokeLayerSpec(angleDeg: 60, stepMm: 3.8, thicknessMm: 0.24),
            StrokeLayerSpec(angleDeg: 120, stepMm: 3.8, thicknessMm: 0.24),
          ],
        ),
        'marl': GostPatternSpec(
          id: 'marl',
          descriptionRu: 'Мергель',
          layers: [
            StrokeLayerSpec(angleDeg: 0, stepMm: 3.6, thicknessMm: 0.20),
            StrokeLayerSpec(angleDeg: 90, stepMm: 3.6, thicknessMm: 0.20),
          ],
        ),
        'silt': GostPatternSpec(
          id: 'silt',
          descriptionRu: 'Алевролит',
          layers: [
            StrokeLayerSpec(angleDeg: 30, stepMm: 2.4, thicknessMm: 0.20),
            StrokeLayerSpec(angleDeg: 150, stepMm: 2.4, thicknessMm: 0.20),
          ],
        ),
        'dolomite': GostPatternSpec(
          id: 'dolomite',
          descriptionRu: 'Доломит',
          layers: [
            StrokeLayerSpec(angleDeg: 0, stepMm: 4.2, thicknessMm: 0.22),
            StrokeLayerSpec(angleDeg: 90, stepMm: 4.2, thicknessMm: 0.22),
          ],
        ),
      },
      defaultColors: const {
        'песок': Color(0xFFE8D9AE),
        'суглинок': Color(0xFFD9BFA9),
        'глина': Color(0xFFC9A28F),
        'песчаник': Color(0xFFD7C7B5),
        'известняк': Color(0xFFDDE5D9),
        'гравий': Color(0xFFB7B7B7),
        'галька': Color(0xFFC7C7C7),
        'мергель': Color(0xFFE5E2C8),
        'алевролит': Color(0xFFD8CDC9),
        'доломит': Color(0xFFE7EEE8),
      },
      legendOrder: const [
        'песок',
        'суглинок',
        'глина',
        'песчаник',
        'известняк',
        'гравий',
        'галька',
        'мергель',
        'алевролит',
        'доломит',
      ],
      legendSampleWidthMm: 18.0,
      legendSampleHeightMm: 12.0,
      tickMajorMeters: 1.0,
      tickMinorMeters: 0.5,
      exportDefaults: exportDefaults,
      exportPaddingMm: exportDefaults.paddingMm,
    );
  }

  GostSet parseToml(String data) {
    final Map<String, dynamic> root = toml.TomlDocument.parse(data).toMap();

    Map<String, String> mapping = {};
    Map<String, String> synonyms = {};
    Map<String, GostPatternSpec> patterns = {};
    Map<String, Color> colors = {};
    List<String> legendOrder = [];
    double legendW = 18.0, legendH = 12.0;
    double tickMajor = 1.0, tickMinor = 0.5;

    double exportPaddingMm = 3.0;
    int exportDpi = 300;
    bool exportTransparent = false;
    if (root['export'] is Map) {
      final Map exp = root['export'] as Map;
      exportPaddingMm = (exp['padding_mm'] as num?)?.toDouble() ?? exportPaddingMm;
      exportDpi = (exp['default_dpi'] as num?)?.toInt() ?? exportDpi;
      exportTransparent = (exp['transparent_background'] as bool?) ?? exportTransparent;
    }
    final ExportDefaults exportDefaults = ExportDefaults(
      paddingMm: exportPaddingMm,
      defaultDpi: exportDpi,
      transparentBackground: exportTransparent,
    );

    if (root['mapping'] is Map) {
      for (final e in (root['mapping'] as Map).entries) {
        mapping['${e.key}'.trim().toLowerCase()] =
            '${e.value}'.trim().toLowerCase();
      }
    }

    if (root['synonyms'] is Map) {
      for (final e in (root['synonyms'] as Map).entries) {
        synonyms['${e.key}'.trim().toLowerCase()] =
            '${e.value}'.trim().toLowerCase();
      }
    }

    if (root['default_colors'] is Map) {
      for (final e in (root['default_colors'] as Map).entries) {
        String hex = '${e.value}'.trim().replaceAll('#', '');
        if (hex.length == 6) hex = 'FF$hex';
        final int argb = int.parse(hex, radix: 16);
        colors['${e.key}'.trim().toLowerCase()] = Color(argb);
      }
    }

    if (root['legend'] is Map) {
      final Map l = root['legend'] as Map;
      final List? order = l['order'] as List?;
      if (order != null) legendOrder = order.map((e) => '$e').toList();
      legendW = (l['sample_w_mm'] as num?)?.toDouble() ?? legendW;
      legendH = (l['sample_h_mm'] as num?)?.toDouble() ?? legendH;
    }

    if (root['ticks'] is Map) {
      final Map t = root['ticks'] as Map;
      tickMajor = (t['major'] as num?)?.toDouble() ?? tickMajor;
      tickMinor = (t['minor'] as num?)?.toDouble() ?? tickMinor;
    }

    if (root['patterns'] is List) {
      for (final pat in (root['patterns'] as List)) {
        final Map p = pat as Map;
        final String id = (p['id'] ?? '').toString();
        if (id.isEmpty) continue;

        final String desc = (p['description_ru'] ?? id).toString();

        final List<StrokeLayerSpec> layerSpecs = <StrokeLayerSpec>[];
        if (p['layers'] is List) {
          for (final rawLayer in (p['layers'] as List)) {
            final Map lm = rawLayer as Map;
            final String type = (lm['type'] ?? 'stroke').toString();

            if (type == 'stroke') {
              final double angle = (lm['angle_deg'] as num?)?.toDouble() ?? 45.0;
              final double step = (lm['step_mm'] as num?)?.toDouble() ?? 2.0;
              final double thick =
                  (lm['thickness_mm'] as num?)?.toDouble() ?? 0.2;
              layerSpecs.add(
                  StrokeLayerSpec(angleDeg: angle, stepMm: step, thicknessMm: thick));
            } else if (type == 'cross_stroke') {
              final double a1 = (lm['angle1_deg'] as num?)?.toDouble() ?? 45.0;
              final double a2 = (lm['angle2_deg'] as num?)?.toDouble() ?? 135.0;
              final double step = (lm['step_mm'] as num?)?.toDouble() ?? 2.0;
              final double thick =
                  (lm['thickness_mm'] as num?)?.toDouble() ?? 0.2;
              layerSpecs.add(
                  StrokeLayerSpec(angleDeg: a1, stepMm: step, thicknessMm: thick));
              layerSpecs.add(
                  StrokeLayerSpec(angleDeg: a2, stepMm: step, thicknessMm: thick));
            } else {
              continue;
            }
          }
        }

        patterns[id] = GostPatternSpec(
          id: id,
          descriptionRu: desc,
          layers: layerSpecs.isNotEmpty
              ? layerSpecs
              : const [
                  StrokeLayerSpec(angleDeg: 45, stepMm: 2.0, thicknessMm: 0.2)
                ],
        );
      }
    }

    return GostSet(
      mapping: mapping,
      synonyms: synonyms,
      patterns: patterns,
      defaultColors: colors,
      legendOrder: legendOrder,
      legendSampleWidthMm: legendW,
      legendSampleHeightMm: legendH,
      tickMajorMeters: tickMajor,
      tickMinorMeters: tickMinor,
      exportDefaults: exportDefaults,
      exportPaddingMm: exportPaddingMm,
    );
  }
}
