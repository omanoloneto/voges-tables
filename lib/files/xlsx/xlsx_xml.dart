import 'package:xml/xml.dart';

abstract final class XlsxNamespaces {
  static const main =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  static const relationships =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const packageRelationships =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  static const contentTypes =
      'http://schemas.openxmlformats.org/package/2006/content-types';
}

const xmlDeclaration =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';

/// Text content escaping, plus the `_xHHHH_` form Excel uses for control
/// characters that XML 1.0 cannot carry.
String escapeText(String value) {
  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    switch (unit) {
      case 0x26:
        buffer.write('&amp;');
      case 0x3C:
        buffer.write('&lt;');
      case 0x3E:
        buffer.write('&gt;');
      case 0x5F when _escapedAt(value, i):
        buffer.write('_x005F_');
      case < 0x20 when unit != 0x09 && unit != 0x0A:
        buffer.write(
          '_x${unit.toRadixString(16).toUpperCase().padLeft(4, '0')}_',
        );
      case 0xFFFE || 0xFFFF:
        break;
      default:
        buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

String escapeAttribute(String value) =>
    escapeText(value).replaceAll('"', '&quot;');

final _escapedCharacter = RegExp(r'_x([0-9A-Fa-f]{4})_');

bool _escapedAt(String value, int index) =>
    _escapedCharacter.matchAsPrefix(value, index) != null;

/// Undoes the `_xHHHH_` escaping of [escapeText].
String unescapeText(String value) {
  if (!value.contains('_x')) return value;
  return value.replaceAllMapped(
    _escapedCharacter,
    (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
  );
}

/// `ST_OnOff`: an element without `val` means on.
bool onOff(String? value) =>
    value == null || value == '1' || value == 'true' || value == 'on';

/// An optional `ST_OnOff` attribute, off when absent.
bool onOffAttribute(XmlElement element, String name) {
  final value = element.getAttribute(name);
  return value != null && onOff(value);
}

XmlElement? child(XmlElement parent, String localName) {
  for (final element in parent.childElements) {
    if (element.name.local == localName) return element;
  }
  return null;
}

Iterable<XmlElement> children(XmlElement parent, String localName) =>
    parent.childElements.where((element) => element.name.local == localName);

/// Reads `r:id` whatever the prefix or namespace (transitional or strict).
String? relationshipId(XmlElement element) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == 'id' && attribute.name.prefix != null) {
      return attribute.value;
    }
  }
  return null;
}
