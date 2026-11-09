import 'dart:typed_data';

import '../../sheet/cell_address.dart';
import '../../sheet/cell_value.dart';
import '../../sheet/chart.dart';
import '../../sheet/workbook.dart';
import 'sheet_names.dart';
import 'xlsx_chart_writer.dart';
import 'xlsx_package.dart';
import 'xlsx_shared_strings.dart';
import 'xlsx_sheet_writer.dart';
import 'xlsx_styles_writer.dart';
import 'xlsx_xml.dart';

const applicationName = 'Voges Tables';

/// Writes [workbook] as an `.xlsx` that Excel, LibreOffice and Google Sheets
/// open without repair. Formulas carry the value [valueOf] gives as their
/// cached result; Excel recalculates everything on open anyway. Charts cache
/// the same values, with [displayOf] as the text of their labels.
///
/// Sheet names Excel would refuse are fixed on the way out (see
/// [safeSheetNames]); the workbook itself is not changed.
Uint8List writeXlsx(
  Workbook workbook, {
  required CellValue Function(int sheetIndex, CellAddress address) valueOf,
  String Function(int sheetIndex, CellAddress address)? displayOf,
  String currencySymbol = r'R$',
  DateTime? now,
}) {
  final styles = XlsxStyleTable(currencySymbol: currencySymbol);
  final strings = SharedStringTable();
  final sheetWriter = XlsxSheetWriter(styles: styles, strings: strings);
  final names = safeSheetNames([for (final s in workbook.sheets) s.name]);
  final chartWriter = XlsxChartWriter(
    workbook,
    sheetNames: names,
    valueOf: valueOf,
    displayOf: displayOf,
  );
  final count = workbook.sheets.length;
  final parts = <String, String>{};
  var drawings = 0, charts = 0;
  for (var i = 0; i < count; i++) {
    final sheet = workbook.sheets[i];
    final drawn = <SheetChart>[];
    for (final chart in sheet.charts) {
      final xml = chartWriter.chart(chart);
      if (xml == null) continue;
      drawn.add(chart);
      parts['xl/charts/chart${charts + drawn.length}.xml'] = xml;
    }
    String? drawingId;
    if (drawn.isNotEmpty) {
      drawings++;
      parts['xl/drawings/drawing$drawings.xml'] = XlsxChartWriter.drawing(
        drawn,
      );
      parts['xl/drawings/_rels/drawing$drawings.xml.rels'] = _relationships([
        for (var n = 1; n <= drawn.length; n++)
          ('chart', '../charts/chart${charts + n}.xml'),
      ]);
      parts['xl/worksheets/_rels/sheet${i + 1}.xml.rels'] = _relationships([
        ('drawing', '../drawings/drawing$drawings.xml'),
      ]);
      charts += drawn.length;
      drawingId = 'rId1';
    }
    parts['xl/worksheets/sheet${i + 1}.xml'] = sheetWriter.write(
      sheet,
      valueOf: (address) => valueOf(i, address),
      selected: i == 0,
      drawingId: drawingId,
    );
  }
  final hasStrings = !strings.isEmpty;
  parts['[Content_Types].xml'] = _contentTypes(
    count,
    hasStrings,
    drawings: drawings,
    charts: charts,
  );
  parts['_rels/.rels'] = _rootRelationships;
  parts['docProps/app.xml'] = _appProperties;
  parts['docProps/core.xml'] = _coreProperties(now ?? DateTime.now());
  parts['xl/workbook.xml'] = _workbook(names);
  parts['xl/_rels/workbook.xml.rels'] = _workbookRelationships(
    count,
    hasStrings,
  );
  parts['xl/styles.xml'] = styles.toXml();
  if (hasStrings) parts['xl/sharedStrings.xml'] = strings.toXml();
  return XlsxPackage.encode(parts);
}

const _relationshipBase =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _spreadsheetType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml';

String _contentTypes(
  int sheets,
  bool hasStrings, {
  required int drawings,
  required int charts,
}) {
  final buffer = StringBuffer(xmlDeclaration)
    ..write(
      '<Types xmlns="${XlsxNamespaces.contentTypes}">'
      '<Default Extension="rels" '
      'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" '
      'ContentType="$_spreadsheetType.sheet.main+xml"/>',
    );
  for (var i = 1; i <= sheets; i++) {
    buffer.write(
      '<Override PartName="/xl/worksheets/sheet$i.xml" '
      'ContentType="$_spreadsheetType.worksheet+xml"/>',
    );
  }
  buffer.write(
    '<Override PartName="/xl/styles.xml" '
    'ContentType="$_spreadsheetType.styles+xml"/>',
  );
  if (hasStrings) {
    buffer.write(
      '<Override PartName="/xl/sharedStrings.xml" '
      'ContentType="$_spreadsheetType.sharedStrings+xml"/>',
    );
  }
  for (var i = 1; i <= drawings; i++) {
    buffer.write(
      '<Override PartName="/xl/drawings/drawing$i.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>',
    );
  }
  for (var i = 1; i <= charts; i++) {
    buffer.write(
      '<Override PartName="/xl/charts/chart$i.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.drawingml.chart+xml"/>',
    );
  }
  buffer.write(
    '<Override PartName="/docProps/core.xml" '
    'ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
    '<Override PartName="/docProps/app.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
    '</Types>',
  );
  return buffer.toString();
}

const _rootRelationships =
    '$xmlDeclaration'
    '<Relationships xmlns="${XlsxNamespaces.packageRelationships}">'
    '<Relationship Id="rId1" Type="$_relationshipBase/officeDocument" '
    'Target="xl/workbook.xml"/>'
    '<Relationship Id="rId2" '
    'Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" '
    'Target="docProps/core.xml"/>'
    '<Relationship Id="rId3" Type="$_relationshipBase/extended-properties" '
    'Target="docProps/app.xml"/>'
    '</Relationships>';

const _appProperties =
    '$xmlDeclaration'
    '<Properties '
    'xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
    'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
    '<Application>$applicationName</Application>'
    '<DocSecurity>0</DocSecurity><ScaleCrop>false</ScaleCrop>'
    '<LinksUpToDate>false</LinksUpToDate><SharedDoc>false</SharedDoc>'
    '<HyperlinksChanged>false</HyperlinksChanged>'
    '</Properties>';

String _coreProperties(DateTime now) {
  final stamp = '${now.toUtc().toIso8601String().split('.').first}Z';
  return '$xmlDeclaration'
      '<cp:coreProperties '
      'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" '
      'xmlns:dcterms="http://purl.org/dc/terms/" '
      'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
      '<dcterms:created xsi:type="dcterms:W3CDTF">$stamp</dcterms:created>'
      '<dcterms:modified xsi:type="dcterms:W3CDTF">$stamp</dcterms:modified>'
      '</cp:coreProperties>';
}

String _workbook(List<String> names) {
  final buffer = StringBuffer(xmlDeclaration)
    ..write(
      '<workbook xmlns="${XlsxNamespaces.main}" '
      'xmlns:r="${XlsxNamespaces.relationships}">'
      '<bookViews><workbookView activeTab="0"/></bookViews><sheets>',
    );
  for (var i = 0; i < names.length; i++) {
    buffer.write(
      '<sheet name="${escapeAttribute(names[i])}" sheetId="${i + 1}" '
      'r:id="rId${i + 1}"/>',
    );
  }
  buffer.write(
    '</sheets><calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>',
  );
  return buffer.toString();
}

String _workbookRelationships(int sheets, bool hasStrings) {
  final buffer = StringBuffer(xmlDeclaration)
    ..write('<Relationships xmlns="${XlsxNamespaces.packageRelationships}">');
  for (var i = 1; i <= sheets; i++) {
    buffer.write(
      '<Relationship Id="rId$i" Type="$_relationshipBase/worksheet" '
      'Target="worksheets/sheet$i.xml"/>',
    );
  }
  buffer.write(
    '<Relationship Id="rId${sheets + 1}" Type="$_relationshipBase/styles" '
    'Target="styles.xml"/>',
  );
  if (hasStrings) {
    buffer.write(
      '<Relationship Id="rId${sheets + 2}" '
      'Type="$_relationshipBase/sharedStrings" Target="sharedStrings.xml"/>',
    );
  }
  buffer.write('</Relationships>');
  return buffer.toString();
}

/// A part's relationships, numbered `rId1`, `rId2`... in order.
String _relationships(List<(String type, String target)> targets) {
  final buffer = StringBuffer(xmlDeclaration)
    ..write('<Relationships xmlns="${XlsxNamespaces.packageRelationships}">');
  for (var i = 0; i < targets.length; i++) {
    final (type, target) = targets[i];
    buffer.write(
      '<Relationship Id="rId${i + 1}" Type="$_relationshipBase/$type" '
      'Target="$target"/>',
    );
  }
  buffer.write('</Relationships>');
  return buffer.toString();
}
