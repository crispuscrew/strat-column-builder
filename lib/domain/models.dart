import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum ExportFormat { png, svg }

class CompositionPart {
  final String lithologyKey;
  final double percent;

  const CompositionPart({
    required this.lithologyKey,
    required this.percent,
  });

  CompositionPart copyWith({String? lithologyKey, double? percent}) =>
      CompositionPart(
        lithologyKey: lithologyKey ?? this.lithologyKey,
        percent: percent ?? this.percent,
      );
}

class StratInterval {
  final double startDepthMeters;
  final double endDepthMeters;
  final String lithologyRaw;
  final String? note;
  final List<CompositionPart>? compositionParts;

  const StratInterval({
    required this.startDepthMeters,
    required this.endDepthMeters,
    required this.lithologyRaw,
    this.note,
    this.compositionParts,
  });

  StratInterval copyWith({
    double? startDepthMeters,
    double? endDepthMeters,
    String? lithologyRaw,
    String? note,
    List<CompositionPart>? compositionParts,
  }) =>
      StratInterval(
        startDepthMeters: startDepthMeters ?? this.startDepthMeters,
        endDepthMeters: endDepthMeters ?? this.endDepthMeters,
        lithologyRaw: lithologyRaw ?? this.lithologyRaw,
        note: note ?? this.note,
        compositionParts: compositionParts ?? this.compositionParts,
      );
}

class StratColumn {
  final List<StratInterval> intervals;
  const StratColumn({required this.intervals});
}

class StrokeLayerSpec {
  final double angleDeg;
  final double stepMm;
  final double thicknessMm;

  const StrokeLayerSpec({
    required this.angleDeg,
    required this.stepMm,
    required this.thicknessMm,
  });
}

class GostPatternSpec {
  final String id;
  final String descriptionRu;
  final List<StrokeLayerSpec> layers;

  const GostPatternSpec({
    required this.id,
    required this.descriptionRu,
    required this.layers,
  });
}

class ExportDefaults {
  final double paddingMm;
  final int defaultDpi;
  final bool transparentBackground;

  const ExportDefaults({
    this.paddingMm = 0.0,
    this.defaultDpi = 300,
    this.transparentBackground = false,
  });
}

class GostSet {
  final Map<String, String> mapping;
  final Map<String, String> synonyms;
  final Map<String, GostPatternSpec> patterns;
  final Map<String, Color> defaultColors;

  final List<String> legendOrder;
  final double legendSampleWidthMm;
  final double legendSampleHeightMm;

  final double tickMajorMeters;
  final double tickMinorMeters;
  final double exportPaddingMm;

  final ExportDefaults exportDefaults;

  const GostSet({
    required this.mapping,
    required this.synonyms,
    required this.patterns,
    required this.defaultColors,
    required this.legendOrder,
    required this.legendSampleWidthMm,
    required this.legendSampleHeightMm,
    required this.tickMajorMeters,
    required this.tickMinorMeters,
    this.exportDefaults = const ExportDefaults(),
    this.exportPaddingMm = 3.0,
  });
}

@immutable
class RenderSpec {
  final double pixelsPerMillimeter;
  final double columnWidthMm;
  final double scaleMmPerMeter;

  final bool showLegend;
  final bool showDepthGrid;
  final bool showIntervalLabels;

  final double previewZoom;

  final String fontFamily;

  final ExportFormat exportFormat;
  final double exportDpi;
  final bool exportTransparentBg;
  final double exportPaddingMm;

  final bool showFooter;

  const RenderSpec({
    required this.pixelsPerMillimeter,
    required this.columnWidthMm,
    required this.scaleMmPerMeter,
    required this.showLegend,
    required this.showDepthGrid,
    required this.showIntervalLabels,
    required this.previewZoom,
    required this.fontFamily,
    this.exportFormat = ExportFormat.png,
    this.exportDpi = 300.0,
    this.exportTransparentBg = false,
    this.exportPaddingMm = 0.0,
    this.showFooter = false,
  });

  RenderSpec copyWith({
    double? pixelsPerMillimeter,
    double? columnWidthMm,
    double? scaleMmPerMeter,
    bool? showLegend,
    bool? showDepthGrid,
    bool? showIntervalLabels,
    double? previewZoom,
    String? fontFamily,
    ExportFormat? exportFormat,
    double? exportDpi,
    bool? exportTransparentBg,
    double? exportPaddingMm,
    bool? showFooter,
  }) {
    return RenderSpec(
      pixelsPerMillimeter: pixelsPerMillimeter ?? this.pixelsPerMillimeter,
      columnWidthMm: columnWidthMm ?? this.columnWidthMm,
      scaleMmPerMeter: scaleMmPerMeter ?? this.scaleMmPerMeter,
      showLegend: showLegend ?? this.showLegend,
      showDepthGrid: showDepthGrid ?? this.showDepthGrid,
      showIntervalLabels:
          showIntervalLabels ?? this.showIntervalLabels,
      previewZoom: previewZoom ?? this.previewZoom,
      fontFamily: fontFamily ?? this.fontFamily,
      exportFormat: exportFormat ?? this.exportFormat,
      exportDpi: exportDpi ?? this.exportDpi,
      exportTransparentBg:
          exportTransparentBg ?? this.exportTransparentBg,
      exportPaddingMm: exportPaddingMm ?? this.exportPaddingMm,
      showFooter: showFooter ?? this.showFooter,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RenderSpec &&
      pixelsPerMillimeter == other.pixelsPerMillimeter &&
      columnWidthMm == other.columnWidthMm &&
      scaleMmPerMeter == other.scaleMmPerMeter &&
      showLegend == other.showLegend &&
      showDepthGrid == other.showDepthGrid &&
      showIntervalLabels == other.showIntervalLabels &&
      previewZoom == other.previewZoom &&
      fontFamily == other.fontFamily &&
      exportFormat == other.exportFormat &&
      exportDpi == other.exportDpi &&
      exportTransparentBg == other.exportTransparentBg &&
      exportPaddingMm == other.exportPaddingMm &&
      showFooter == other.showFooter;

  @override
  int get hashCode => Object.hash(
        pixelsPerMillimeter,
        columnWidthMm,
        scaleMmPerMeter,
        showLegend,
        showDepthGrid,
        showIntervalLabels,
        previewZoom,
        fontFamily,
        exportFormat,
        exportDpi,
        exportTransparentBg,
        exportPaddingMm,
        showFooter,
      );
}
