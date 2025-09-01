import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../domain/models.dart';
import '../domain/validation.dart';
import '../rendering/column_painter.dart';
import '../services/gost_service.dart';
import '../services/import_service.dart';
import 'settings_panel.dart';

final columnProvider = StateProvider<StratColumn?>((ref) => null);
final gostSetProvider = StateProvider<GostSet?>((ref) => null);
final renderSpecProvider = StateProvider<RenderSpec>(
  (ref) => const RenderSpec(
    pixelsPerMillimeter: 3.0,
    columnWidthMm: 50.0,
    scaleMmPerMeter: 10.0,
    showLegend: true,
    showDepthGrid: true,
    showIntervalLabels: true,
    previewZoom: 1.5,
    fontFamily: 'GOST_Type_A',
  ),
);

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ImportService importService = ImportService();
  final GostService gostService = GostService();
  final GlobalKey repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    gostService.loadBuiltin().then((g) {
      ref.read(gostSetProvider.notifier).state = g;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final StratColumn? stratColumn = ref.watch(columnProvider);
    final GostSet? gostSet = ref.watch(gostSetProvider);
    final RenderSpec renderSpec = ref.watch(renderSpecProvider);
    final bool hasData =
        stratColumn != null && stratColumn.intervals.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Стратиграфическая колонка — ГОСТ 21.302-2013'),
        actions: [
          IconButton(
            tooltip: 'Открыть CSV/TXT',
            onPressed: _onOpenDataFile,
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            tooltip: 'Профиль ГОСТ',
            onPressed: _onOpenGostProfile,
            icon: const Icon(Icons.tune),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFFF7F7F7),
              child: Listener(
                onPointerSignal: (PointerSignalEvent event) {
                  if (event is PointerScrollEvent) {
                    final bool ctrl = HardwareKeyboard
                            .instance.logicalKeysPressed
                            .contains(LogicalKeyboardKey.controlLeft) ||
                        HardwareKeyboard.instance.logicalKeysPressed
                            .contains(LogicalKeyboardKey.controlRight);
                    if (ctrl) {
                      final RenderSpec spec = ref.read(renderSpecProvider);
                      final double z0 = spec.previewZoom;
                      final bool zoomInInverted = !(event.scrollDelta.dy > 0);
                      final double factor = zoomInInverted ? 1.1 : 0.9;
                      final double z1 = (z0 * factor).clamp(0.5, 3.0);
                      ref.read(renderSpecProvider.notifier).state =
                          spec.copyWith(previewZoom: z1);
                    }
                  }
                },
                child: RepaintBoundary(
                  key: repaintKey,
                  child: Stack(
                    children: [
                      CustomPaint(
                        painter: (hasData && gostSet != null)
                            ? StratColumnPainter(
                                column: stratColumn!,
                                gostSet: gostSet,
                                renderSpec: renderSpec,
                              )
                            : null,
                        child: const SizedBox.expand(),
                      ),
                      if (!hasData)
                        Center(
                          child: _EmptyState(
                            onOpenDataFile: _onOpenDataFile,
                            onOpenGostProfile: _onOpenGostProfile,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 340,
            child: SettingsPanel(
              repaintKey: repaintKey,
              onOpenDataFile: _onOpenDataFile,
              onOpenGostProfile: _onOpenGostProfile,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onOpenDataFile() async {
    final XTypeGroup typeGroup =
        const XTypeGroup(label: 'CSV or TXT', extensions: ['csv', 'txt']);
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    final Uint8List bytes = await file.readAsBytes();
    final ImportResult result = await importService.parseBytes(bytes);

    if (result.errors.isNotEmpty) {
      final ImportErrorInfo err = result.errors.first;
      await _showErrorDialog(
        'Ошибка импорта: строка ${err.rowIndex} — ${err.messageRu}',
      );
      return;
    }
    if (mounted) {
      ref.read(columnProvider.notifier).state = result.column;
      if (result.warnings.isNotEmpty) {
        final String text = result.warnings
            .map((ImportWarningInfo w) => 'Строка ${w.rowIndex}: ${w.messageRu}')
            .join('\n');
        await _showInfoDialog('Предупреждения импорта', text);
      }
    }
  }

  Future<void> _onOpenGostProfile() async {
    final XTypeGroup typeGroup =
        const XTypeGroup(label: 'TOML', extensions: ['toml']);
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    try {
      final String data = await file.readAsString();
      final GostSet newSet = GostService().parseToml(data);
      if (mounted) {
        ref.read(gostSetProvider.notifier).state = newSet;
      }
    } catch (e) {
      await _showErrorDialog('Ошибка загрузки профиля ГОСТ: ${e.toString()}');
    }
  }

  Future<void> _showErrorDialog(String message) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ошибка'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _showInfoDialog(String title, String message) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ок'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onOpenDataFile;
  final VoidCallback onOpenGostProfile;

  const _EmptyState({
    required this.onOpenDataFile,
    required this.onOpenGostProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Загрузите данные для построения колонки',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: onOpenDataFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Открыть CSV/TXT'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onOpenGostProfile,
                  icon: const Icon(Icons.tune),
                  label: const Text('Выбрать профиль ГОСТ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
