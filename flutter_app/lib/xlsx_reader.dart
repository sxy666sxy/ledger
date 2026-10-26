import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Minimal, robust XLSX reader.
/// It deliberately ignores the styles/numFmt validity checks that make
/// package:excel throw on some WPS/Excel files ("numFmtId starts at 164").
List<List<String>> readXlsxRows(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  ArchiveFile? find(String name) {
    for (final f in archive.files) {
      if (f.name == name) return f;
    }
    return null;
  }

  String? readText(String name) {
    final f = find(name);
    if (f == null) return null;
    try {
      final content = f.content;
      if (content is String) return content;
      if (content is List<int>) return utf8.decode(content);
      return content.toString();
    } catch (_) {
      return null;
    }
  }

  // Shared strings
  final shared = <String>[];
  final sharedText = readText('xl/sharedStrings.xml');
  if (sharedText != null) {
    final doc = XmlDocument.parse(sharedText);
    for (final si in doc.findAllElements('si')) {
      final parts = si.findAllElements('t').map((e) => e.innerText).join();
      shared.add(parts);
    }
  }

  // Styles: only need to know which style indexes are date formats.
  final dateStyles = <int>{};
  final stylesText = readText('xl/styles.xml');
  if (stylesText != null) {
    try {
      final doc = XmlDocument.parse(stylesText);
      final custom = <int, String>{};
      for (final fmt in doc.findAllElements('numFmt')) {
        final id = int.tryParse(fmt.getAttribute('numFmtId') ?? '');
        final code = fmt.getAttribute('formatCode') ?? '';
        if (id != null) custom[id] = code;
      }
      const builtinDate = {14, 15, 16, 17, 18, 19, 20, 21, 22, 45, 46, 47};
      XmlElement? cellXfs;
      for (final e in doc.findAllElements('cellXfs')) {
        cellXfs = e;
        break;
      }
      var index = 0;
      if (cellXfs != null) {
        for (final xf in cellXfs.findElements('xf')) {
          final numFmtId = int.tryParse(xf.getAttribute('numFmtId') ?? '0') ?? 0;
          final code = custom[numFmtId] ?? '';
          final looksDate = builtinDate.contains(numFmtId) ||
              RegExp(r'[ymdhs]', caseSensitive: false).hasMatch(code);
          if (looksDate) dateStyles.add(index);
          index++;
        }
      }
    } catch (_) {
      // Malformed style tables should not block reading values.
    }
  }

  // Use the first worksheet. WPS/Excel files from the wild normally use sheet1.
  String? sheetPath;
  for (final f in archive.files) {
    if (RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name)) {
      if (sheetPath == null || f.name.compareTo(sheetPath) < 0) sheetPath = f.name;
    }
  }
  if (sheetPath == null) {
    for (final f in archive.files) {
      if (f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml')) {
        sheetPath = f.name;
        break;
      }
    }
  }
  if (sheetPath == null) return <List<String>>[];
  final sheetText = readText(sheetPath);
  if (sheetText == null) return <List<String>>[];

  try {
    final doc = XmlDocument.parse(sheetText);
    final rows = <List<String>>[];
    for (final row in doc.findAllElements('row')) {
      final cells = <int, String>{};
      var maxCol = 0;
      for (final c in row.findElements('c')) {
        final ref = c.getAttribute('r') ?? '';
        final col = _columnIndex(ref);
        final t = c.getAttribute('t');
        final style = int.tryParse(c.getAttribute('s') ?? '');
        final vElement = _first(c, 'v');
        final inlineElement = _first(c, 'is');
        final v = vElement?.innerText.trim();
        String value = '';
        if (t == 's') {
          final idx = int.tryParse(v ?? '');
          if (idx != null && idx >= 0 && idx < shared.length) value = shared[idx];
        } else if (t == 'inlineStr') {
          value = inlineElement == null
              ? (v ?? '')
              : inlineElement.findAllElements('t').map((e) => e.innerText).join();
        } else if (t == 'b') {
          value = (v == '1') ? 'TRUE' : 'FALSE';
        } else if (t == 'str' || t == 'e') {
          value = v ?? '';
        } else if (v != null && v.isNotEmpty) {
          final number = double.tryParse(v);
          if (number != null && style != null && dateStyles.contains(style)) {
            value = _excelDate(number);
          } else {
            value = v;
          }
        }
        cells[col] = value.trim();
        if (col > maxCol) maxCol = col;
      }
      final list = List<String>.filled(maxCol + 1, '');
      cells.forEach((k, v) { list[k] = v; });
      rows.add(list);
    }
    return rows;
  } catch (e) {
    throw FormatException('无法读取 Excel 工作表：$e');
  }
}

XmlElement? _first(XmlElement e, String name) {
  for (final x in e.findElements(name)) {
    return x;
  }
  return null;
}

int _columnIndex(String ref) {
  var col = 0;
  for (var i = 0; i < ref.length; i++) {
    final code = ref.codeUnitAt(i);
    if (code < 65 || code > 90) break;
    col = col * 26 + (code - 64);
  }
  return col > 0 ? col - 1 : 0;
}

String _excelDate(double serial) {
  final dt = DateTime(1899, 12, 30).add(Duration(milliseconds: (serial * 86400000).round()));
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
