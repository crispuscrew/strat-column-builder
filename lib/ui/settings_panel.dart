import 'dart:typed_data' show Uint8List;

import 'package:cross_file/cross_file.dart' show XFile;
import 'package:file_selector/file_selector.dart'
    show getSaveLocation, XTypeGroup, FileSaveLocation;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../domain/models.dart';
import '../services/export_service.dart';
import 'home_page.dart';

const bool kSvgExportDisabled = true;

class SettingsPanel extends ConsumerWidget {
  final GlobalKey repaintKey;
  final VoidCallback onOpenDataFile;
  final VoidCallback onOpenGostProfile;

  const SettingsPanel({
    super.key,
    required this.repaintKey,
    required this.onOpenDataFile,
    required this.onOpenGostProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RenderSpec renderSpec = ref.watch(renderSpecProvider);
    final StratColumn? stratColumn = ref.watch(columnProvider);
    final GostSet? gostSet = ref.watch(gostSetProvider);
    final bool hasData = stratColumn != null && stratColumn.intervals.isNotEmpty;

    if (kSvgExportDisabled && renderSpec.exportFormat == ExportFormat.svg) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(renderSpecProvider.notifier)
            .state = renderSpec.copyWith(exportFormat: ExportFormat.png);
      });
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onOpenGostProfile,
                icon: const Icon(Icons.tune),
                label: const Text('Профиль ГОСТ'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onOpenDataFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Открыть CSV/TXT'),
              ),
            ),
          ]),
          const Divider(height: 24),
          const Text('Настройки', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _check(
            context,
            'Показывать легенду',
            renderSpec.showLegend,
            (v) => ref.read(renderSpecProvider.notifier)
                .state = renderSpec.copyWith(showLegend: v),
          ),
          _check(
            context,
            'Сетка глубин',
            renderSpec.showDepthGrid,
            (v) => ref.read(renderSpecProvider.notifier)
                .state = renderSpec.copyWith(showDepthGrid: v),
          ),
          _check(
            context,
            'Подписи интервалов',
            renderSpec.showIntervalLabels,
            (v) => ref.read(renderSpecProvider.notifier)
                .state = renderSpec.copyWith(showIntervalLabels: v),
          ),
          const SizedBox(height: 12),
          const Text('Масштаб (мм на 1 м):'),
          Slider(
            min: 2.0,
            max: 30.0,
            divisions: 28,
            value: renderSpec.scaleMmPerMeter.clamp(2.0, 30.0),
            label: renderSpec.scaleMmPerMeter.toStringAsFixed(1),
            onChanged: (v) => ref.read(renderSpecProvider.notifier)
                .state = renderSpec.copyWith(scaleMmPerMeter: v),
          ),
          const SizedBox(height: 8),
          const Text('Масштаб предпросмотра:'),
          Slider(
            min: 0.25,
            max: 4.0,
            divisions: 30,
            value: renderSpec.previewZoom.clamp(0.25, 4.0),
            label: '${(renderSpec.previewZoom * 100).round()}%',
            onChanged: (v) => ref.read(renderSpecProvider.notifier)
                .state = renderSpec.copyWith(previewZoom: v),
          ),
          const Text(
            'Колесо + Ctrl — инвертированное увеличение/уменьшение.',
            style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
          ),
          const Divider(height: 24),
          const Text('Экспорт:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ToggleButtons(
            isSelected: const [true, false],
            onPressed: (index) {
              if (index == 0) {
                ref.read(renderSpecProvider.notifier)
                    .state = renderSpec.copyWith(exportFormat: ExportFormat.png);
              } else {
                if (kSvgExportDisabled) {
                  _snack(context, 'SVG-экспорт временно отключён');
                }
              }
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text('PNG'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text('SVG (скоро)'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DPI для PNG:'),
              Slider(
                min: 96,
                max: 600,
                divisions: 504,
                value: renderSpec.exportDpi.clamp(96, 600),
                label: '${renderSpec.exportDpi.round()} dpi',
                onChanged: (v) => ref.read(renderSpecProvider.notifier)
                    .state = renderSpec.copyWith(exportDpi: v),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Прозрачный фон'),
                value: renderSpec.exportTransparentBg,
                onChanged: (v) => ref.read(renderSpecProvider.notifier).state =
                    renderSpec.copyWith(exportTransparentBg: v ?? false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: hasData ? () => _exportToFile(context, ref) : null,
                child: const Text('PNG в файл'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed:
                    hasData ? () => _exportToClipboard(context, ref) : null,
                child: const Text('PNG в буфер'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _check(
    BuildContext context,
    String title,
    bool value,
    ValueChanged<bool> onChange,
  ) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title),
      value: value,
      onChanged: (v) => onChange(v ?? false),
    );
  }

  Future<void> _exportToFile(BuildContext context, WidgetRef ref) async {
    final StratColumn? column = ref.read(columnProvider);
    final GostSet? gost = ref.read(gostSetProvider);
    final RenderSpec spec = ref.read(renderSpecProvider);

    if (column == null || column.intervals.isEmpty || gost == null) {
      await _snack(context, 'Нечего экспортировать');
      return;
    }

    final Uint8List bytes = await _capturePng(ref);
    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: 'strat_column.png',
      acceptedTypeGroups: [const XTypeGroup(label: 'PNG', extensions: ['png'])],
    );
    if (location == null || location.path == null || location.path!.isEmpty) {
      return;
    }
    await XFile.fromData(
      bytes,
      mimeType: 'image/png',
      name: 'strat_column.png',
    ).saveTo(location.path!);
    await _snack(context, 'PNG сохранён: ${location.path!}');
  }

  Future<void> _exportToClipboard(
      BuildContext context, WidgetRef ref) async {
    final StratColumn? column = ref.read(columnProvider);
    final GostSet? gost = ref.read(gostSetProvider);
    final RenderSpec spec = ref.read(renderSpecProvider);

    if (column == null || column.intervals.isEmpty || gost == null) {
      await _snack(context, 'Нечего копировать');
      return;
    }

    await _snack(
        context, 'PNG в буфер пока не поддерживается на этой сборке');
  }

  Future<Uint8List> _capturePng(WidgetRef ref) async {
    final StratColumn column = ref.read(columnProvider)!;
    final GostSet gost = ref.read(gostSetProvider)!;
    final RenderSpec spec = ref.read(renderSpecProvider);

    final Uint8List bytes = await ExportService.renderPngTight(
      column,
      gost,
      spec,
      options: ExportOptions(
        paddingMm: gost.exportPaddingMm,
        pngPixelRatio: (spec.exportDpi / 96.0).clamp(1.0, 10.0),
        includeFooter: false,
        transparentBackground: spec.exportTransparentBg,
      ),
    );
    return bytes;
  }

  Future<void> _snack(BuildContext context, String text) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}