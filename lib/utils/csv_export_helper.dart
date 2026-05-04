import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CsvExportHelper {
  static Future<void> exportRowsToClipboard({
    required BuildContext context,
    required String fileLabel,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('No data available to export for $fileLabel.')),
        );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escapeCell).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCell).join(','));
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${rows.length} rows for $fileLabel. CSV copied to clipboard.',
          ),
        ),
      );
  }

  static String _escapeCell(String value) {
    final sanitized = value.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();
    final escaped = sanitized.replaceAll('"', '""');
    return '"$escaped"';
  }
}
