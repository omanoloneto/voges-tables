import 'dart:typed_data';

import '../../sheet/cell_address.dart';
import '../../sheet/cell_value.dart';
import '../../sheet/workbook.dart';
import 'sheet_names.dart';
import 'xlsx_package.dart';
import 'xlsx_shared_strings.dart';
import 'xlsx_sheet_writer.dart';
import 'xlsx_styles_writer.dart';
import 'xlsx_xml.dart';

const applicationName = 'Voges Tables';

/// Writes [workbook] as an `.xlsx` that Excel, LibreOffice and Google Sheets
/// open without repair. Formulas carry the value [valueOf] gives as their
/// cached result; Excel recalculates everything on open anyway.
///
/// Sheet names Excel would refuse are fixed on the way out (see
/// [safeSheetNames]); the workbook itself is not changed.
Uint8List writeXlsx(
  Workbook workbook, {
  required CellValue Function(int sheetIndex, CellAddress address) valueOf,
  String currencySymbol = r'R$',
  DateTime? now,
}) {
  final styles = XlsxStyleTable(currencySymbol: currencySymbol);
  final strings = SharedStringTable();
  final sheetWriter = XlsxSheetWriter(styles: styles, strings: strings);
  final count = workbook.sheets.length;
  final parts = <String, String>{};
  for (var i = 0; i < count; i++) {
    parts['xl/worksheets/sheet${i + 1}.xml'] = sheetWriter.write(
      workbook.sheets[i],
      valueOf: (address) => valueOf(i, address),
      selected: i == 0,
    );
  }
  final names = safeSheetNames([for (final s in workbook.sheets) s.name]);
  final hasStrings = !strings.isEmpty;
  parts['[Content_Types].xml'] = _contentTypes(count, hasStrings);
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

String _contentTypes(int sheets, bool hasStrings) {
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
