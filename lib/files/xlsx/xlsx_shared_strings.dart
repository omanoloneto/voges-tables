import 'package:xml/xml_events.dart';

import 'xlsx_xml.dart';

/// Collects the text of a string item (`<si>` or `<is>`): plain `<t>` or rich
/// text runs flattened, without the phonetic guides (`<rPh>`).
class StringItemText {
  final _buffer = StringBuffer();
  var _inText = false;
  var _phonetic = 0;

  void start(XmlStartElementEvent event) {
    switch (event.localName) {
      case 't' when _phonetic == 0 && !event.isSelfClosing:
        _inText = true;
      case 'rPh' when !event.isSelfClosing:
        _phonetic++;
    }
  }

  void end(XmlEndElementEvent event) {
    switch (event.localName) {
      case 't':
        _inText = false;
      case 'rPh':
        _phonetic--;
    }
  }

  void text(String value) {
    if (_inText) _buffer.write(value);
  }

  String take() {
    final value = unescapeText(_buffer.toString());
    _buffer.clear();
    _inText = false;
    _phonetic = 0;
    return value;
  }
}

List<String> readSharedStrings(String? source) {
  if (source == null) return const [];
  final strings = <String>[];
  final item = StringItemText();
  var inItem = false;
  for (final event in parseEvents(source)) {
    switch (event) {
      case XmlStartElementEvent(localName: 'si', isSelfClosing: final closed):
        if (closed) {
          strings.add('');
        } else {
          inItem = true;
        }
      case XmlStartElementEvent() when inItem:
        item.start(event);
      case XmlEndElementEvent(localName: 'si'):
        inItem = false;
        strings.add(item.take());
      case XmlEndElementEvent() when inItem:
        item.end(event);
      case XmlTextEvent(:final value) when inItem:
        item.text(value);
      case XmlCDATAEvent(:final value) when inItem:
        item.text(value);
      default:
        break;
    }
  }
  return strings;
}

/// The shared string table built while the sheets are written.
class SharedStringTable {
  final _indexes = <String, int>{};
  var _count = 0;

  bool get isEmpty => _indexes.isEmpty;

  int indexOf(String text) {
    _count++;
    return _indexes.putIfAbsent(text, () => _indexes.length);
  }

  String toXml() {
    final buffer = StringBuffer(xmlDeclaration)
      ..write(
        '<sst xmlns="${XlsxNamespaces.main}" count="$_count" '
        'uniqueCount="${_indexes.length}">',
      );
    for (final text in _indexes.keys) {
      final preserve = text.trim() != text || text.contains('\n');
      buffer
        ..write(preserve ? '<si><t xml:space="preserve">' : '<si><t>')
        ..write(escapeText(text))
        ..write('</t></si>');
    }
    buffer.write('</sst>');
    return buffer.toString();
  }
}
