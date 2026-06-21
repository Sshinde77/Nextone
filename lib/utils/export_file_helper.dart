import 'dart:io';

class ExportFileHelper {
  static Future<File> saveToDownloadNextone({
    required String fileName,
    required List<int> bytes,
  }) async {
    final sanitizedFileName =
        fileName.trim().isEmpty ? 'export.xlsx' : fileName.trim();
    final candidateDirs = <String>[
      '/storage/emulated/0/Download/nextone',
      '/sdcard/Download/nextone',
    ];

    for (final dirPath in candidateDirs) {
      try {
        final dir = Directory(dirPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final file = File('${dir.path}/$sanitizedFileName');
        await file.writeAsBytes(bytes, flush: true);
        return file;
      } catch (_) {
        // Try next location.
      }
    }

    final fallback = File('${Directory.systemTemp.path}/$sanitizedFileName');
    await fallback.writeAsBytes(bytes, flush: true);
    return fallback;
  }
}
