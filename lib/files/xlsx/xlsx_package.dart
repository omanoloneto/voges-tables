import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../spreadsheet_file_exception.dart';

class Relationship {
  const Relationship({
    required this.id,
    required this.type,
    required this.target,
  });

  final String id;
  final String type;
  final String target;

  /// Matches both transitional and strict OOXML relationship types.
  bool hasType(String suffix) => type.endsWith('/$suffix');
}

/// The parts of an `.xlsx` zip, read lazily so only what is used is inflated.
class XlsxPackage {
  XlsxPackage._(this._archive);

  factory XlsxPackage.decode(Uint8List bytes) {
    _rejectNonZip(bytes);
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw SpreadsheetFileException(SpreadsheetProblem.notSpreadsheet);
    }
    final declaredSize = archive.files.fold<int>(0, (sum, f) => sum + f.size);
    if (declaredSize > maxUncompressedBytes) {
      throw SpreadsheetFileException(SpreadsheetProblem.tooLarge);
    }
    return XlsxPackage._(archive);
  }

  /// Guards against compressed files that blow up in memory.
  static const maxUncompressedBytes = 1024 * 1024 * 1024;

  final Archive _archive;

  static const _zipMagic = [0x50, 0x4B, 0x03, 0x04];
  static const _compoundMagic = [
    0xD0,
    0xCF,
    0x11,
    0xE0,
    0xA1,
    0xB1,
    0x1A,
    0xE1,
  ];

  /// `.xls` files and password-protected `.xlsx` files are both OLE compound
  /// files; the encrypted ones hold an `EncryptedPackage` stream.
  static void _rejectNonZip(Uint8List bytes) {
    if (_startsWith(bytes, _zipMagic)) return;
    if (_startsWith(bytes, _compoundMagic)) {
      final marker = [
        for (final unit in 'EncryptedPackage'.codeUnits) ...[unit, 0],
      ];
      throw SpreadsheetFileException(
        _contains(bytes, marker)
            ? SpreadsheetProblem.encrypted
            : SpreadsheetProblem.legacyExcel,
      );
    }
    throw SpreadsheetFileException(SpreadsheetProblem.notSpreadsheet);
  }

  static bool _startsWith(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  static bool _contains(Uint8List bytes, List<int> pattern) {
    outer:
    for (var i = 0; i <= bytes.length - pattern.length; i++) {
      for (var j = 0; j < pattern.length; j++) {
        if (bytes[i + j] != pattern[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  bool has(String path) => _archive.findFile(path) != null;

  String? text(String path) {
    final file = _archive.findFile(path);
    if (file == null || !file.isFile) return null;
    final decoded = utf8.decode(file.content, allowMalformed: true);
    return decoded.startsWith('\uFEFF') ? decoded.substring(1) : decoded;
  }

  XmlDocument? xml(String path) {
    final source = text(path);
    if (source == null) return null;
    try {
      return XmlDocument.parse(source);
    } on XmlException {
      throw SpreadsheetFileException(
        SpreadsheetProblem.notSpreadsheet,
        'Malformed XML in $path',
      );
    }
  }

  List<Relationship> relationships(String sourcePath) {
    final document = xml(relationshipsPath(sourcePath));
    if (document == null) return const [];
    return [
      for (final element in document.rootElement.childElements)
        if (element.name.local == 'Relationship')
          Relationship(
            id: element.getAttribute('Id') ?? '',
            type: element.getAttribute('Type') ?? '',
            target: element.getAttribute('Target') ?? '',
          ),
    ];
  }

  static String relationshipsPath(String sourcePath) {
    if (sourcePath.isEmpty) return '_rels/.rels';
    final slash = sourcePath.lastIndexOf('/');
    final directory = slash < 0 ? '' : sourcePath.substring(0, slash + 1);
    return '${directory}_rels/${sourcePath.substring(slash + 1)}.rels';
  }

  static String resolve(String sourcePath, String target) {
    if (target.startsWith('/')) return target.substring(1);
    final slash = sourcePath.lastIndexOf('/');
    final segments = slash < 0
        ? <String>[]
        : sourcePath.substring(0, slash).split('/');
    for (final segment in target.split('/')) {
      if (segment == '..') {
        if (segments.isNotEmpty) segments.removeLast();
      } else if (segment.isNotEmpty && segment != '.') {
        segments.add(segment);
      }
    }
    return segments.join('/');
  }

  /// Builds a zip with `[Content_Types].xml` first, as Office expects.
  static Uint8List encode(Map<String, String> parts) {
    final archive = Archive();
    const contentTypes = '[Content_Types].xml';
    final names = [
      if (parts.containsKey(contentTypes)) contentTypes,
      ...parts.keys.where((name) => name != contentTypes),
    ];
    for (final name in names) {
      archive.addFile(ArchiveFile.bytes(name, utf8.encode(parts[name]!)));
    }
    return ZipEncoder().encodeBytes(archive);
  }
}
