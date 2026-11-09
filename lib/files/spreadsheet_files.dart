import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'spreadsheet_format.dart';

/// The formats Save writes.
enum SaveFormat {
  xlsx('xlsx', 'Excel (.xlsx)'),
  csv('csv', 'CSV (.csv)');

  const SaveFormat(this.extension, this.label);

  final String extension;
  final String label;

  static SaveFormat? of(String name) {
    final lower = name.toLowerCase();
    for (final format in values) {
      if (lower.endsWith('.${format.extension}')) return format;
    }
    return null;
  }
}

List<String> get openableExtensions => SpreadsheetFormat.openExtensions;

class OpenedFile {
  const OpenedFile({required this.name, required this.bytes, this.path});

  final String name;
  final Uint8List bytes;

  /// Where Save can write back; null when the file came as a copy.
  final String? path;
}

/// Titles of the system file dialogs, in the user's language.
class FileDialogTitles {
  const FileDialogTitles({this.open = 'Open', this.save = 'Save'});

  final String open;
  final String save;
}

/// Opens and saves files with the system dialogs.
class SpreadsheetFiles {
  FileDialogTitles titles = const FileDialogTitles();

  Future<OpenedFile?> pick() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: titles.open,
      type: FileType.custom,
      allowedExtensions: openableExtensions,
    );
    final path = result?.files.single.path;
    return path == null ? null : read(path);
  }

  Future<OpenedFile> read(String path) async => OpenedFile(
    name: path.split(Platform.pathSeparator).last,
    bytes: await File(path).readAsBytes(),
    path: path,
  );

  /// The path the user chose, with the format's extension; null if canceled.
  Future<String?> chooseSaveLocation(String name, SaveFormat format) async {
    final path = await FilePicker.saveFile(
      dialogTitle: titles.save,
      fileName: name,
      type: FileType.custom,
      allowedExtensions: [format.extension],
    );
    if (path == null) return null;
    return SaveFormat.of(path) == format ? path : '$path.${format.extension}';
  }

  Future<void> write(String path, Uint8List bytes) =>
      File(path).writeAsBytes(bytes, flush: true);
}
