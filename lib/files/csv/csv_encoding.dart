import 'dart:convert';
import 'dart:typed_data';

const _utf8Bom = [0xEF, 0xBB, 0xBF];

/// UTF-8 with a BOM: without it Excel reads the accents as Windows-1252.
Uint8List encodeCsv(String text) =>
    Uint8List.fromList([..._utf8Bom, ...utf8.encode(text)]);

/// UTF-8 (with or without BOM) or UTF-16 with BOM, the "Unicode text" Excel
/// saves; bytes that are not valid UTF-8 are read as Windows-1252, the
/// encoding of CSV files saved by Excel in Brazil and Western Europe.
String decodeCsv(Uint8List bytes) {
  if (_startsWith(bytes, _utf8Bom)) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  if (_startsWith(bytes, const [0xFF, 0xFE])) {
    return _utf16(bytes, little: true);
  }
  if (_startsWith(bytes, const [0xFE, 0xFF])) {
    return _utf16(bytes, little: false);
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return _windows1252(bytes);
  }
}

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

String _utf16(Uint8List bytes, {required bool little}) {
  final units = <int>[];
  for (var i = 2; i + 1 < bytes.length; i += 2) {
    units.add(
      little ? bytes[i] | bytes[i + 1] << 8 : bytes[i] << 8 | bytes[i + 1],
    );
  }
  return String.fromCharCodes(units);
}

/// Where Windows-1252 differs from Latin-1 (0x80–0x9F); 0 marks the five
/// unassigned bytes, kept as their Latin-1 control characters.
const _windows1252High = [
  0x20AC, 0, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0, 0x017D, 0,
  0, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0, 0x017E, 0x0178,
];

String _windows1252(Uint8List bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    final mapped = byte >= 0x80 && byte <= 0x9F
        ? _windows1252High[byte - 0x80]
        : 0;
    buffer.writeCharCode(mapped == 0 ? byte : mapped);
  }
  return buffer.toString();
}
