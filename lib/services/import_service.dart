import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import '../domain/models.dart';
import '../domain/validation.dart';

class ImportResult {
  final StratColumn? column;
  final List<ImportErrorInfo> errors;
  final List<ImportWarningInfo> warnings;

  ImportResult({this.column, required this.errors, required this.warnings});
}

class ImportService {
  Future<ImportResult> parseBytes(Uint8List bytes) async {
    String content = _decodeBytes(bytes);
    final String delimiter = _detectDelimiter(content);
    final CsvToListConverter conv = CsvToListConverter(
      fieldDelimiter: delimiter,
      eol: '\n',
      shouldParseNumbers: false,
    );
    final List<List<dynamic>> rows = conv.convert(content);

    if (rows.isEmpty) {
      return ImportResult(
        errors: [ImportErrorInfo(rowIndex: 1, messageRu: 'Файл пуст')],
        warnings: [],
      );
    }

    final Map<String, int> headerIndex = _mapHeaders(rows.first);
    if (!headerIndex.containsKey('from') ||
        !headerIndex.containsKey('to') ||
        !headerIndex.containsKey('lithology')) {
      return ImportResult(
        errors: [
          ImportErrorInfo(
            rowIndex: 1,
            messageRu:
                'Обязательные столбцы не найдены: требуется "от|from", "до|to", "литология|lithology"',
          )
        ],
        warnings: [],
      );
    }

    final List<StratInterval> intervals = [];
    final List<ImportErrorInfo> errors = [];
    final List<ImportWarningInfo> warnings = [];

    for (int i = 1; i < rows.length; i++) {
      final List<dynamic> row = rows[i];
      if (row.isEmpty ||
          row.every((e) => (e?.toString().trim().isEmpty ?? true))) {
        continue;
      }
      try {
        final String fromStr = (row[headerIndex['from']!]).toString().trim();
        final String toStr = (row[headerIndex['to']!]).toString().trim();

        final double startDepth = _parseNumber(fromStr);
        final double endDepth = _parseNumber(toStr);

        if (startDepth < 0 || endDepth < 0) {
          errors.add(
            ImportErrorInfo(
              rowIndex: i + 1,
              messageRu: 'Значения глубин должны быть неотрицательными',
            ),
          );
          continue;
        }
        if (endDepth <= startDepth) {
          errors.add(
            ImportErrorInfo(
              rowIndex: i + 1,
              messageRu: 'Столбец "до|to" должен быть больше "от|from"',
            ),
          );
          continue;
        }

        final String lithology =
            row[headerIndex['lithology']!].toString().trim();

        List<CompositionPart>? compositionParts;
        final int? compositionIdx = headerIndex['composition'];
        if (compositionIdx != null && compositionIdx < row.length) {
          final String compositionRaw = row[compositionIdx].toString();
          if (compositionRaw.trim().isNotEmpty) {
            compositionParts = _parseComposition(compositionRaw);
          }
        }

        String? note;
        if (headerIndex.containsKey('note') &&
            headerIndex['note']! < row.length) {
          note = row[headerIndex['note']!]?.toString().trim();
        }

        intervals.add(
          StratInterval(
            startDepthMeters: startDepth,
            endDepthMeters: endDepth,
            lithologyRaw: lithology,
            compositionParts: compositionParts,
            note: note,
          ),
        );
      } catch (e) {
        errors.add(
          ImportErrorInfo(
            rowIndex: i + 1,
            messageRu: 'Ошибка разбора строки: ${e.toString()}',
          ),
        );
      }
    }

    intervals.sort((a, b) => a.startDepthMeters.compareTo(b.startDepthMeters));
    for (int j = 1; j < intervals.length; j++) {
      if (intervals[j].startDepthMeters < intervals[j - 1].endDepthMeters) {
        warnings.add(
          ImportWarningInfo(
            rowIndex: j + 1,
            messageRu:
                'Пересечение интервалов: начало меньше предыдущего конца',
          ),
        );
      }
    }

    return ImportResult(
      column: StratColumn(intervals: intervals),
      errors: errors,
      warnings: warnings,
    );
  }

  String _decodeBytes(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return const Latin1Codec().decode(bytes);
    }
  }

  String _detectDelimiter(String content) {
    final int countComma = _count(content, ',');
    final int countSemicolon = _count(content, ';');
    final int countTab = _count(content, '\t');
    if (countTab >= countSemicolon && countTab >= countComma) return '\t';
    if (countSemicolon >= countComma) return ';';
    return ',';
  }

  int _count(String s, String c) => s.split(c).length - 1;

  Map<String, int> _mapHeaders(List<dynamic> headerRow) {
    final Map<String, int> map = {};
    for (int i = 0; i < headerRow.length; i++) {
      final String raw = headerRow[i].toString().trim().toLowerCase();
      final String normalized = switch (raw) {
        'от' || 'from' => 'from',
        'до' || 'to' => 'to',
        'литология' || 'lithology' => 'lithology',
        'примечание' || 'note' => 'note',
        'цвет' || 'color' => 'color',
        'узор' || 'pattern' => 'pattern',
        'состав' || 'composition' => 'composition',
        _ => raw,
      };
      map[normalized] = i;
    }
    return map;
  }

  double _parseNumber(String s) {
    final String t = s.replaceAll(',', '.');
    return double.parse(t);
  }

  List<CompositionPart> _parseComposition(String raw) {
    final List<CompositionPart> parts = [];
    final List<String> chunks = raw.split(';');
    for (final chunk in chunks) {
      final String c = chunk.trim();
      if (c.isEmpty) continue;
      final List<String> kv = c.split(':');
      if (kv.length != 2) continue;
      final String lithKey = kv[0].trim().toLowerCase();
      final double pct = double.tryParse(kv[1].trim()) ?? 0.0;
      parts.add(CompositionPart(lithologyKey: lithKey, percent: pct));
    }
    final double sum = parts.fold(0.0, (a, b) => a + b.percent);
    if (sum > 0) {
      return parts
          .map((p) => CompositionPart(
                lithologyKey: p.lithologyKey,
                percent: p.percent * 100.0 / sum,
              ))
          .toList();
    }
    return parts;
  }
}
