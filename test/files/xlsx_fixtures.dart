import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Hand-built `.xlsx` packages that mimic what Excel and LibreOffice write.

Uint8List zipParts(Map<String, String> parts) {
  final archive = Archive();
  parts.forEach(
    (name, content) =>
        archive.addFile(ArchiveFile.bytes(name, utf8.encode(content))),
  );
  return ZipEncoder().encodeBytes(archive);
}

const _main = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const _rel =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _pkgRel = 'http://schemas.openxmlformats.org/package/2006/relationships';

const _rootRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="$_pkgRel">'
    '<Relationship Id="rId1" Type="$_rel/officeDocument" '
    'Target="xl/workbook.xml"/></Relationships>';

const _contentTypes =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '</Types>';

/// Excel 365 in Portuguese: the sheets are listed in an order different from
/// their part names, with shared strings, shared and array formulas, a theme
/// with a custom accent, built-in number formats and a frozen pane.
Uint8List excelWorkbook() => zipParts({
  '[Content_Types].xml': _contentTypes,
  '_rels/.rels': _rootRels,
  'xl/workbook.xml':
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="$_main" xmlns:r="$_rel">'
      '<workbookPr defaultThemeVersion="166925"/>'
      '<bookViews><workbookView activeTab="0"/></bookViews>'
      '<sheets>'
      '<sheet name="Resumo &amp; Totais" sheetId="2" r:id="rId2"/>'
      '<sheet name="Dados" sheetId="1" r:id="rId1"/>'
      '<sheet name="Gráfico" sheetId="3" r:id="rId6"/>'
      '</sheets><calcPr calcId="191029"/></workbook>',
  'xl/_rels/workbook.xml.rels':
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="$_pkgRel">'
      '<Relationship Id="rId1" Type="$_rel/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="$_rel/worksheet" Target="/xl/worksheets/sheet2.xml"/>'
      '<Relationship Id="rId3" Type="$_rel/theme" Target="theme/theme1.xml"/>'
      '<Relationship Id="rId4" Type="$_rel/styles" Target="styles.xml"/>'
      '<Relationship Id="rId5" Type="$_rel/sharedStrings" Target="sharedStrings.xml"/>'
      '<Relationship Id="rId6" Type="$_rel/chartsheet" Target="chartsheets/sheet1.xml"/>'
      '</Relationships>',
  'xl/theme/theme1.xml':
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office">'
      '<a:themeElements><a:clrScheme name="Office">'
      '<a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>'
      '<a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>'
      '<a:dk2><a:srgbClr val="44546A"/></a:dk2>'
      '<a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>'
      '<a:accent1><a:srgbClr val="123456"/></a:accent1>'
      '<a:accent2><a:srgbClr val="ED7D31"/></a:accent2>'
      '<a:accent3><a:srgbClr val="A5A5A5"/></a:accent3>'
      '<a:accent4><a:srgbClr val="FFC000"/></a:accent4>'
      '<a:accent5><a:srgbClr val="5B9BD5"/></a:accent5>'
      '<a:accent6><a:srgbClr val="70AD47"/></a:accent6>'
      '<a:hlink><a:srgbClr val="0563C1"/></a:hlink>'
      '<a:folHlink><a:srgbClr val="954F72"/></a:folHlink>'
      '</a:clrScheme></a:themeElements></a:theme>',
  'xl/styles.xml':
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="$_main">'
      '<numFmts count="3">'
      r'<numFmt numFmtId="164" formatCode="&quot;R$&quot;\ #,##0.00"/>'
      '<numFmt numFmtId="165" formatCode="0.000"/>'
      r'<numFmt numFmtId="166" formatCode="[$-416]d\ mmmm\ yyyy;@"/>'
      '</numFmts>'
      '<fonts count="4">'
      '<font><sz val="11"/><color theme="1"/><name val="Calibri"/><family val="2"/><scheme val="minor"/></font>'
      '<font><b/><sz val="11"/><color theme="1"/><name val="Calibri"/></font>'
      '<font><i/><strike/><u val="double"/><sz val="14"/><color rgb="FFFF0000"/><name val="Calibri"/></font>'
      '<font><b val="0"/><sz val="11"/><color theme="4"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="4">'
      '<fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFFFFF00"/><bgColor indexed="64"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor theme="0" tint="-0.499984740745262"/><bgColor indexed="64"/></patternFill></fill>'
      '</fills>'
      '<borders count="3">'
      '<border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border><left style="thin"><color indexed="64"/></left><right style="thin"><color indexed="64"/></right>'
      '<top style="thin"><color indexed="64"/></top><bottom style="thin"><color indexed="64"/></bottom><diagonal/></border>'
      '<border><left/><right/><top/><bottom style="medium"><color auto="1"/></bottom><diagonal/></border>'
      '</borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="15">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="14" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="22" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="9" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="10" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="44" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">'
      '<alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="2" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1">'
      '<alignment horizontal="right" vertical="top"/></xf>'
      '<xf numFmtId="0" fontId="3" fillId="3" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
      '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="3" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="20" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="49" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="166" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>',
  'xl/sharedStrings.xml':
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<sst xmlns="$_main" count="5" uniqueCount="4">'
      '<si><t>Produto</t></si>'
      '<si><r><rPr><b/></rPr><t>Rich</t></r><r><t xml:space="preserve"> text</t></r>'
      '<rPh sb="0" eb="1"><t>フリガナ</t></rPh></si>'
      '<si><t xml:space="preserve">  line one_x000D_\nline two </t></si>'
      '<si><t/></si>'
      '</sst>',
  'xl/worksheets/sheet1.xml':
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="$_main" xmlns:r="$_rel"><dimension ref="A1:B2"/>'
      '<sheetData>'
      '<row r="1"><c r="A1"><v>1</v></c><c r="B1"><v>2.5</v></c></row>'
      '<row r="2"><c r="A2" s="1"><v>45658</v></c></row>'
      '</sheetData></worksheet>',
  'xl/worksheets/sheet2.xml':
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="$_main" xmlns:r="$_rel">'
      '<dimension ref="A1:H6"/>'
      '<sheetViews><sheetView tabSelected="1" workbookViewId="0">'
      '<pane xSplit="1" ySplit="2" topLeftCell="B3" activePane="bottomRight" state="frozen"/>'
      '<selection pane="bottomRight" activeCell="B3" sqref="B3"/>'
      '</sheetView><sheetView workbookViewId="1"><pane ySplit="9" state="frozen"/></sheetView></sheetViews>'
      '<sheetFormatPr defaultRowHeight="15" x14ac:dyDescent="0.25" '
      'xmlns:x14ac="http://schemas.microsoft.com/office/spreadsheetml/2009/9/ac"/>'
      '<cols>'
      '<col min="1" max="1" width="20.7109375" customWidth="1"/>'
      '<col min="3" max="5" width="9.140625" customWidth="1"/>'
      '<col min="6" max="6" width="15" style="3"/>'
      '</cols>'
      '<sheetData>'
      '<row r="1" spans="1:8" ht="30" customHeight="1">'
      '<c r="A1" t="s"><v>0</v></c>'
      '<c r="B1" s="6"><v>1234.5</v></c>'
      '<c r="C1" t="b"><v>1</v></c>'
      '<c r="D1" t="e"><v>#DIV/0!</v></c>'
      '<c r="E1" t="inlineStr"><is><r><t>Inline </t></r><r><rPr><i/></rPr><t>rich</t></r></is></c>'
      '<c r="F1"><f t="array" ref="F1:F3">SUM(B1:B3*C1:C3)</f><v>6</v></c>'
      '<c r="G1" t="s" s="7"><v>1</v></c>'
      '<c r="H1" t="s"><v>2</v></c>'
      '</row>'
      '<row r="2" spans="1:8">'
      '<c r="A2"><f t="shared" ref="A2:A4" si="0">B2*\$C\$1+SUM(B\$2:B2)+\'Other Sheet\'!A2</f><v>3</v></c>'
      '<c r="B2" s="2"><v>45658.75</v></c>'
      '<c r="C2" s="3"><v>0.25</v></c>'
      '<c r="D2" s="4"><v>0.125</v></c>'
      '<c r="E2" s="5"><v>10</v></c>'
      '<c r="F2"><v>2</v></c>'
      '<c r="G2" s="8" t="str"><f>_xlfn.IFS(B2&gt;1,"big",TRUE,"small")</f><v>big</v></c>'
      '</row>'
      '<row r="3" ht="15">'
      '<c r="A3"><f t="shared" si="0"/><v>4</v></c>'
      '<c r="B3" s="9"><v>7</v></c>'
      '<c r="C3" s="10"><v>3.14159</v></c>'
      '<c r="D3" s="11"><v>1000000</v></c>'
      '<c r="E3" s="12"><v>0.5</v></c>'
      '<c r="F3"><v>2</v></c>'
      '<c r="G3" s="13" t="s"><v>3</v></c>'
      '<c r="H3" s="14"><v>45000</v></c>'
      '</row>'
      '<row r="4">'
      '<c r="A4"><f t="shared" si="0"/><v>5</v></c>'
      '<c><v>11</v></c><c t="s"><v>0</v></c>'
      '</row>'
      '<row ht="22.5" customHeight="1"><c r="H5" s="7"/><c r="G5"/></row>'
      '<row r="6"><c r="A6" t="str"><v>formula-less str</v></c>'
      '<c r="B6" t="d"><v>2024-01-02T12:00:00</v></c>'
      '<c r="C6" t="e"><v>#SPILL!</v></c></row>'
      '</sheetData>'
      '<mergeCells count="1"><mergeCell ref="A10:B10"/></mergeCells>'
      '<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>'
      '</worksheet>',
});

/// LibreOffice Calc: Arial 10 as the default font, a default `<col>` over
/// most columns, a height on every row and `true`/`false` booleans.
Uint8List libreOfficeWorkbook() => zipParts({
  '[Content_Types].xml': _contentTypes,
  '_rels/.rels': _rootRels,
  'xl/workbook.xml':
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="$_main" xmlns:r="$_rel">'
      '<workbookPr backupFile="false" showObjects="all" date1904="false"/>'
      '<sheets><sheet name="Planilha1" sheetId="1" state="visible" r:id="rId2"/></sheets>'
      '</workbook>',
  'xl/_rels/workbook.xml.rels':
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<Relationships xmlns="$_pkgRel">'
      '<Relationship Id="rId1" Type="$_rel/styles" Target="styles.xml"/>'
      '<Relationship Id="rId2" Type="$_rel/worksheet" Target="worksheets/sheet1.xml"/>'
      '</Relationships>',
  'xl/styles.xml':
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="$_main">'
      '<numFmts count="1"><numFmt numFmtId="164" formatCode="&quot;R\$ &quot;#,##0.00;[RED]&quot;-R\$ &quot;#,##0.00"/></numFmts>'
      '<fonts count="2">'
      '<font><sz val="10"/><name val="Arial"/><family val="2"/></font>'
      '<font><b val="true"/><sz val="10"/><name val="Arial"/><family val="2"/></font>'
      '</fonts>'
      '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
      '<borders count="1"><border diagonalUp="false" diagonalDown="false"><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellXfs count="3">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" applyFont="false" applyBorder="false" applyAlignment="false" applyProtection="false">'
      '<alignment horizontal="general" vertical="bottom" textRotation="0" wrapText="false" indent="0" shrinkToFit="false"/></xf>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" applyFont="true"/>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" applyFont="false"/>'
      '</cellXfs></styleSheet>',
  'xl/worksheets/sheet1.xml':
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="$_main" xmlns:r="$_rel">'
      '<sheetViews><sheetView showGridLines="true" workbookViewId="0">'
      '<pane xSplit="0" ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
      '</sheetView></sheetViews>'
      '<sheetFormatPr defaultColWidth="11.53515625" defaultRowHeight="12.8" zeroHeight="false" outlineLevelRow="0" outlineLevelCol="0"/>'
      '<cols>'
      '<col collapsed="false" customWidth="true" hidden="false" outlineLevel="0" max="1" min="1" style="0" width="25.5"/>'
      '<col collapsed="false" customWidth="false" hidden="false" outlineLevel="0" max="1024" min="2" style="0" width="11.53515625"/>'
      '</cols>'
      '<sheetData>'
      '<row r="1" customFormat="false" ht="12.8" hidden="false" customHeight="false" outlineLevel="0" collapsed="false">'
      '<c r="A1" s="1" t="inlineStr"><is><t>Nome</t></is></c>'
      '<c r="B1" s="1" t="inlineStr"><is><t>Valor</t></is></c></row>'
      '<row r="2" customFormat="false" ht="12.8" hidden="false" customHeight="false" outlineLevel="0" collapsed="false">'
      '<c r="A2" s="0" t="inlineStr"><is><t>Café</t></is></c>'
      '<c r="B2" s="2" t="n"><v>12.5</v></c>'
      '<c r="C2" s="0" t="b"><v>true</v></c>'
      '<c r="D2" s="0" t="n"><f aca="false">B2*2</f><v>25</v></c></row>'
      '<row r="3" customFormat="false" ht="40.5" hidden="false" customHeight="true" outlineLevel="0" collapsed="false">'
      '<c r="A3" s="0"/></row>'
      '</sheetData></worksheet>',
});

/// The OpenXML SDK style: every element carries an `x:` prefix.
Uint8List prefixedWorkbook({bool date1904 = false}) => zipParts({
  '[Content_Types].xml': _contentTypes,
  '_rels/.rels': _rootRels,
  'xl/workbook.xml':
      '<x:workbook xmlns:x="$_main" xmlns:r="$_rel">'
      '<x:workbookPr${date1904 ? ' date1904="1"' : ''}/>'
      '<x:sheets><x:sheet name="Sheet A" sheetId="1" r:id="R1"/></x:sheets>'
      '</x:workbook>',
  'xl/_rels/workbook.xml.rels':
      '<Relationships xmlns="$_pkgRel">'
      '<Relationship Id="R1" Type="$_rel/worksheet" Target="sheet.xml"/>'
      '<Relationship Id="R2" Type="$_rel/sharedStrings" Target="strings.xml"/>'
      '<Relationship Id="R3" Type="$_rel/styles" Target="styles.xml"/>'
      '</Relationships>',
  'xl/strings.xml':
      '<x:sst xmlns:x="$_main"><x:si><x:t>hello</x:t></x:si></x:sst>',
  'xl/styles.xml':
      '<x:styleSheet xmlns:x="$_main">'
      '<x:fonts><x:font><x:sz val="11"/></x:font></x:fonts>'
      '<x:cellXfs><x:xf numFmtId="0" fontId="0"/><x:xf numFmtId="14" fontId="0"/></x:cellXfs>'
      '</x:styleSheet>',
  'xl/sheet.xml':
      '<x:worksheet xmlns:x="$_main"><x:sheetData>'
      '<x:row r="1"><x:c r="A1" t="s"><x:v>0</x:v></x:c>'
      '<x:c r="B1" s="1"><x:v>0</x:v></x:c>'
      '<x:c r="C1"><x:f>A1&amp;"!"</x:f></x:c></x:row>'
      '</x:sheetData></x:worksheet>',
});

const _c = 'http://schemas.openxmlformats.org/drawingml/2006/chart';
const _a = 'http://schemas.openxmlformats.org/drawingml/2006/main';
const _xdr =
    'http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing';
const _mc = 'http://schemas.openxmlformats.org/markup-compatibility/2006';

/// A one-sheet workbook whose sheet XML is [sheet], with the extra [parts].
Uint8List workbookWithSheet(
  String sheet, {
  String name = 'Planilha1',
  Map<String, String> parts = const {},
}) => zipParts({
  '[Content_Types].xml': _contentTypes,
  '_rels/.rels': _rootRels,
  'xl/workbook.xml':
      '<workbook xmlns="$_main" xmlns:r="$_rel">'
      '<sheets><sheet name="$name" sheetId="1" r:id="rId1"/></sheets>'
      '</workbook>',
  'xl/_rels/workbook.xml.rels':
      '<Relationships xmlns="$_pkgRel">'
      '<Relationship Id="rId1" Type="$_rel/worksheet" Target="worksheets/sheet1.xml"/>'
      '</Relationships>',
  'xl/worksheets/sheet1.xml': sheet,
  ...parts,
});

/// Merges as other producers may write them: overlapping, of one cell,
/// beyond the last column or row, or not a range at all.
const mergesSheet =
    '<worksheet xmlns="$_main"><sheetData>'
    '<row r="1"><c r="A1"><v>1</v></c></row>'
    '</sheetData>'
    '<mergeCells count="9">'
    '<mergeCell ref="B2:C3"/>'
    '<mergeCell ref="A1:B2"/>'
    '<mergeCell ref="C3:D4"/>'
    '<mergeCell ref="E1"/>'
    '<mergeCell ref="F1:F1"/>'
    '<mergeCell ref="XFC1:XFZ2"/>'
    '<mergeCell ref="A1048575:B1048590"/>'
    '<mergeCell ref="nonsense"/>'
    '<mergeCell ref="H8:G7"/>'
    '</mergeCells>'
    '<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>'
    '</worksheet>';

const _excelChartSheet =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<worksheet xmlns="$_main" xmlns:r="$_rel" '
    'xmlns:mc="$_mc" mc:Ignorable="x14ac" '
    'xmlns:x14ac="http://schemas.microsoft.com/office/spreadsheetml/2009/9/ac">'
    '<dimension ref="A1:C6"/>'
    '<sheetViews><sheetView tabSelected="1" workbookViewId="0"/></sheetViews>'
    '<sheetFormatPr defaultRowHeight="15" x14ac:dyDescent="0.25"/>'
    '<cols>'
    '<col min="2" max="2" width="14.28515625" customWidth="1"/>'
    '<col min="3" max="3" width="21.42578125" customWidth="1"/>'
    '</cols>'
    '<sheetData>'
    '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c>'
    '<c r="C1" t="s"><v>2</v></c></row>'
    '<row r="2"><c r="A2" t="s"><v>3</v></c><c r="B2"><v>10</v></c>'
    '<c r="C2"><v>15</v></c></row>'
    '<row r="3"><c r="A3" t="s"><v>4</v></c><c r="B3"><v>20</v></c>'
    '<c r="C3"><v>15</v></c></row>'
    '<row r="4"><c r="A4" t="s"><v>5</v></c><c r="B4"><v>30</v></c>'
    '<c r="C4"><f>C2+10</f><v>25</v></c></row>'
    '<row r="6"><c r="A6" t="s"><v>6</v></c></row>'
    '<row r="21" ht="30" customHeight="1"/>'
    '</sheetData>'
    '<mergeCells count="1"><mergeCell ref="A6:C6"/></mergeCells>'
    '<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>'
    '<pageSetup paperSize="9" orientation="portrait" r:id="rId1"/>'
    '<drawing r:id="rId2"/>'
    '</worksheet>';

const _excelSharedStrings =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<sst xmlns="$_main" count="7" uniqueCount="7">'
    '<si><t>Mês</t></si><si><t>Loja A</t></si><si><t>Meta</t></si>'
    '<si><t>Jan</t></si><si><t>Fev</t></si><si><t>Mar</t></si>'
    '<si><t>Resumo do trimestre</t></si>'
    '</sst>';

String _graphicFrame(int id, String name) =>
    '<xdr:graphicFrame macro=""><xdr:nvGraphicFramePr>'
    '<xdr:cNvPr id="${id + 1}" name="$name"><a:extLst>'
    '<a:ext uri="{FF2B5EF4-FFF2-40B4-BE49-F238E27FC236}">'
    '<a16:creationId xmlns:a16="http://schemas.microsoft.com/office/drawing/2014/main" '
    'id="{6F1E2A3B-0000-4C5D-8E9F-00000000000$id}"/></a:ext></a:extLst></xdr:cNvPr>'
    '<xdr:cNvGraphicFramePr/></xdr:nvGraphicFramePr>'
    '<xdr:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></xdr:xfrm>'
    '<a:graphic><a:graphicData uri="$_c">'
    '<c:chart xmlns:c="$_c" xmlns:r="$_rel" r:id="rId$id"/>'
    '</a:graphicData></a:graphic></xdr:graphicFrame>';

String _marker(int column, int columnOffset, int row, int rowOffset) =>
    '<xdr:col>$column</xdr:col><xdr:colOff>$columnOffset</xdr:colOff>'
    '<xdr:row>$row</xdr:row><xdr:rowOff>$rowOffset</xdr:rowOff>';

String _anchor(String from, String to, String content) =>
    '<xdr:twoCellAnchor editAs="oneCell">'
    '<xdr:from>$from</xdr:from><xdr:to>$to</xdr:to>'
    '$content<xdr:clientData/></xdr:twoCellAnchor>';

const _picture =
    '<xdr:pic><xdr:nvPicPr><xdr:cNvPr id="5" name="Imagem 5"/>'
    '<xdr:cNvPicPr><a:picLocks noChangeAspect="1"/></xdr:cNvPicPr></xdr:nvPicPr>'
    '<xdr:blipFill><a:blip xmlns:r="$_rel" r:embed="rId5"/>'
    '<a:stretch><a:fillRect/></a:stretch></xdr:blipFill>'
    '<xdr:spPr><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></xdr:spPr></xdr:pic>';

/// How Excel anchors the newer chart kinds (waterfall, treemap...): a
/// `chartEx` frame for those who know it, a text box for the others.
const _chartExFrame =
    '<mc:AlternateContent xmlns:mc="$_mc">'
    '<mc:Choice xmlns:cx1="http://schemas.microsoft.com/office/drawing/2015/9/8/chartex" Requires="cx1">'
    '<xdr:graphicFrame macro=""><xdr:nvGraphicFramePr><xdr:cNvPr id="8" name="Gráfico 7"/>'
    '<xdr:cNvGraphicFramePr/></xdr:nvGraphicFramePr>'
    '<xdr:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></xdr:xfrm>'
    '<a:graphic><a:graphicData uri="http://schemas.microsoft.com/office/drawing/2014/chartex">'
    '<cx:chart xmlns:cx="http://schemas.microsoft.com/office/drawing/2014/chartex" '
    'xmlns:r="$_rel" r:id="rId7"/></a:graphicData></a:graphic></xdr:graphicFrame>'
    '</mc:Choice><mc:Fallback>'
    '<xdr:sp macro="" textlink=""><xdr:nvSpPr><xdr:cNvPr id="0" name=""/><xdr:cNvSpPr/></xdr:nvSpPr>'
    '<xdr:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="4572000" cy="2743200"/></a:xfrm></xdr:spPr>'
    '<xdr:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r>'
    "<a:t>This chart isn't available in your version of Excel.</a:t>"
    '</a:r></a:p></xdr:txBody></xdr:sp>'
    '</mc:Fallback></mc:AlternateContent>';

final _excelDrawing =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<xdr:wsDr xmlns:xdr="$_xdr" xmlns:a="$_a">'
    '${_anchor(_marker(4, 304800, 1, 9525), _marker(11, 0, 16, 85725), _graphicFrame(1, 'Gráfico 1'))}'
    '<xdr:oneCellAnchor><xdr:from>${_marker(1, 0, 20, 0)}</xdr:from>'
    '<xdr:ext cx="2857500" cy="952500"/>'
    '${_graphicFrame(2, 'Gráfico 2')}<xdr:clientData/></xdr:oneCellAnchor>'
    '${_anchor(_marker(0, 0, 30, 0), _marker(5, 0, 40, 0), _graphicFrame(3, 'Gráfico 3'))}'
    '${_anchor(_marker(0, 0, 42, 0), _marker(5, 0, 50, 0), _graphicFrame(4, 'Gráfico 4'))}'
    '${_anchor(_marker(0, 0, 52, 0), _marker(5, 0, 60, 0), _graphicFrame(6, 'Gráfico 6'))}'
    '${_anchor(_marker(6, 0, 30, 0), _marker(9, 0, 40, 0), _picture)}'
    '${_anchor(_marker(10, 0, 30, 0), _marker(17, 0, 45, 0), _chartExFrame)}'
    '<xdr:absoluteAnchor><xdr:pos x="0" y="0"/><xdr:ext cx="914400" cy="914400"/>'
    '${_graphicFrame(1, 'Gráfico 8')}<xdr:clientData/></xdr:absoluteAnchor>'
    '</xdr:wsDr>';

const _textProperties =
    '<c:txPr><a:bodyPr rot="-60000000" spcFirstLastPara="1" vertOverflow="ellipsis" '
    'vert="horz" wrap="square" anchor="ctr" anchorCtr="1"/><a:lstStyle/>'
    '<a:p><a:pPr><a:defRPr sz="900" b="0" i="0" u="none" strike="noStrike" kern="1200" baseline="0">'
    '<a:solidFill><a:schemeClr val="tx1"><a:lumMod val="65000"/><a:lumOff val="35000"/></a:schemeClr></a:solidFill>'
    '<a:latin typeface="+mn-lt"/><a:ea typeface="+mn-ea"/><a:cs typeface="+mn-cs"/></a:defRPr></a:pPr>'
    '<a:endParaRPr lang="pt-BR"/></a:p></c:txPr>';

const _chartStyle =
    '<mc:AlternateContent xmlns:mc="$_mc">'
    '<mc:Choice Requires="c14" xmlns:c14="http://schemas.microsoft.com/office/drawing/2007/8/2/chart">'
    '<c14:style val="102"/></mc:Choice><mc:Fallback><c:style val="2"/></mc:Fallback>'
    '</mc:AlternateContent>';

const _gridlines =
    '<c:majorGridlines><c:spPr><a:ln w="9525" cap="flat" cmpd="sng" algn="ctr">'
    '<a:solidFill><a:schemeClr val="tx1"><a:lumMod val="15000"/><a:lumOff val="85000"/>'
    '</a:schemeClr></a:solidFill><a:round/></a:ln><a:effectLst/></c:spPr></c:majorGridlines>';

String _axis(String tag, String id, String crossing, String position) =>
    '<c:$tag><c:axId val="$id"/><c:scaling><c:orientation val="minMax"/></c:scaling>'
    '<c:delete val="0"/><c:axPos val="$position"/>'
    '${tag == 'valAx' ? _gridlines : ''}'
    '<c:numFmt formatCode="General" sourceLinked="1"/>'
    '<c:majorTickMark val="none"/><c:minorTickMark val="none"/><c:tickLblPos val="nextTo"/>'
    '<c:spPr><a:noFill/><a:ln><a:noFill/></a:ln><a:effectLst/></c:spPr>$_textProperties'
    '<c:crossAx val="$crossing"/><c:crosses val="autoZero"/>'
    '${tag == 'catAx' ? '<c:auto val="1"/><c:lblAlgn val="ctr"/><c:lblOffset val="100"/><c:noMultiLvlLbl val="0"/>' : '<c:crossBetween val="between"/>'}'
    '</c:$tag>';

/// Excel 365's clustered column chart, with everything it adds around the
/// data: styles, caches, unique ids and print settings.
final _excelColumnChart =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<c:chartSpace xmlns:c="$_c" xmlns:a="$_a" xmlns:r="$_rel" '
    'xmlns:c16r2="http://schemas.microsoft.com/office/drawing/2015/06/chart">'
    '<c:date1904 val="0"/><c:lang val="pt-BR"/><c:roundedCorners val="0"/>'
    '$_chartStyle'
    '<c:chart><c:title><c:tx><c:rich>'
    '<a:bodyPr rot="0" spcFirstLastPara="1" vertOverflow="ellipsis" vert="horz" '
    'wrap="square" anchor="ctr" anchorCtr="1"/>'
    '<a:lstStyle/><a:p><a:pPr><a:defRPr sz="1400" b="0"/></a:pPr>'
    '<a:r><a:rPr lang="pt-BR"/><a:t>Vendas por </a:t></a:r>'
    '<a:r><a:rPr lang="pt-BR" b="1"/><a:t>mês</a:t></a:r></a:p>'
    '<a:p><a:r><a:rPr lang="pt-BR"/><a:t>2026</a:t></a:r></a:p>'
    '</c:rich></c:tx><c:overlay val="0"/>'
    '<c:spPr><a:noFill/><a:ln><a:noFill/></a:ln><a:effectLst/></c:spPr></c:title>'
    '<c:autoTitleDeleted val="0"/><c:plotArea><c:layout/>'
    '<c:barChart><c:barDir val="col"/><c:grouping val="clustered"/><c:varyColors val="0"/>'
    '<c:ser><c:idx val="0"/><c:order val="0"/>'
    "<c:tx><c:strRef><c:f>'Vendas 2026'!\$B\$1</c:f><c:strCache><c:ptCount val=\"1\"/>"
    '<c:pt idx="0"><c:v>Loja A</c:v></c:pt></c:strCache></c:strRef></c:tx>'
    '<c:spPr><a:solidFill><a:schemeClr val="accent1"/></a:solidFill>'
    '<a:ln><a:noFill/></a:ln><a:effectLst/></c:spPr>'
    '<c:invertIfNegative val="0"/>'
    "<c:cat><c:strRef><c:f>'Vendas 2026'!\$A\$2:\$A\$4</c:f><c:strCache><c:ptCount val=\"3\"/>"
    '<c:pt idx="0"><c:v>Jan</c:v></c:pt><c:pt idx="1"><c:v>Fev</c:v></c:pt>'
    '<c:pt idx="2"><c:v>Mar</c:v></c:pt></c:strCache></c:strRef></c:cat>'
    "<c:val><c:numRef><c:f>'Vendas 2026'!\$B\$2:\$B\$4</c:f><c:numCache>"
    '<c:formatCode>General</c:formatCode><c:ptCount val="3"/>'
    '<c:pt idx="0"><c:v>10</c:v></c:pt><c:pt idx="1"><c:v>20</c:v></c:pt>'
    '<c:pt idx="2"><c:v>30</c:v></c:pt></c:numCache></c:numRef></c:val>'
    '<c:extLst><c:ext uri="{C3380CC4-5D6E-409C-BE32-E72D297353CC}" '
    'xmlns:c16="http://schemas.microsoft.com/office/drawing/2014/chart">'
    '<c16:uniqueId val="{00000000-6C1A-4F1B-9C2D-000000000001}"/></c:ext></c:extLst></c:ser>'
    '<c:ser><c:idx val="1"/><c:order val="1"/><c:tx><c:v>Meta</c:v></c:tx>'
    '<c:spPr><a:solidFill><a:schemeClr val="accent2"/></a:solidFill></c:spPr>'
    '<c:invertIfNegative val="0"/>'
    "<c:cat><c:strRef><c:f>'Vendas 2026'!\$A\$2:\$A\$4</c:f></c:strRef></c:cat>"
    "<c:val><c:numRef><c:f>'Vendas 2026'!\$C\$2:\$C\$4</c:f><c:numCache>"
    '<c:formatCode>General</c:formatCode><c:ptCount val="3"/>'
    '<c:pt idx="0"><c:v>15</c:v></c:pt><c:pt idx="1"><c:v>15</c:v></c:pt>'
    '<c:pt idx="2"><c:v>25</c:v></c:pt></c:numCache></c:numRef></c:val></c:ser>'
    '<c:dLbls><c:showLegendKey val="0"/><c:showVal val="0"/><c:showCatName val="0"/>'
    '<c:showSerName val="0"/><c:showPercent val="0"/><c:showBubbleSize val="0"/></c:dLbls>'
    '<c:gapWidth val="219"/><c:overlap val="-27"/>'
    '<c:axId val="1903567024"/><c:axId val="1903573264"/></c:barChart>'
    '${_axis('catAx', '1903567024', '1903573264', 'b')}'
    '${_axis('valAx', '1903573264', '1903567024', 'l')}'
    '<c:spPr><a:noFill/><a:ln><a:noFill/></a:ln><a:effectLst/></c:spPr>'
    '</c:plotArea>'
    '<c:legend><c:legendPos val="b"/><c:overlay val="0"/>'
    '<c:spPr><a:noFill/><a:ln><a:noFill/></a:ln><a:effectLst/></c:spPr>$_textProperties</c:legend>'
    '<c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/>'
    '<c:extLst><c:ext uri="{56B9EC1D-385E-4148-901F-78D8002777C0}" '
    'xmlns:c16r3="http://schemas.microsoft.com/office/drawing/2017/03/chart">'
    '<c16r3:dataDisplayOptions16><c16r3:dispNaAsBlank val="1"/></c16r3:dataDisplayOptions16>'
    '</c:ext></c:extLst></c:chart>'
    '<c:spPr><a:solidFill><a:schemeClr val="bg1"/></a:solidFill>'
    '<a:ln w="9525" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="tx1">'
    '<a:lumMod val="15000"/><a:lumOff val="85000"/></a:schemeClr></a:solidFill><a:round/></a:ln>'
    '<a:effectLst/></c:spPr>'
    '<c:txPr><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr/></a:pPr>'
    '<a:endParaRPr lang="pt-BR"/></a:p></c:txPr>'
    '<c:printSettings><c:headerFooter/>'
    '<c:pageMargins b="0.75" l="0.7" r="0.7" t="0.75" header="0.3" footer="0.3"/>'
    '<c:pageSetup/></c:printSettings></c:chartSpace>';

/// A 3D pie without title or legend, a series name Voges Tables cannot
/// link (two areas) and a series of typed-in numbers it cannot read.
const _excelPieChart =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<c:chartSpace xmlns:c="$_c" xmlns:a="$_a" xmlns:r="$_rel">'
    '<c:roundedCorners val="0"/>$_chartStyle'
    '<c:chart><c:autoTitleDeleted val="1"/>'
    '<c:view3D><c:rotX val="30"/><c:rotY val="0"/><c:rAngAx val="0"/></c:view3D>'
    '<c:plotArea><c:layout/><c:pie3DChart><c:varyColors val="1"/>'
    '<c:ser><c:idx val="0"/><c:order val="0"/>'
    "<c:tx><c:strRef><c:f>('Vendas 2026'!\$B\$1,'Vendas 2026'!\$C\$1)</c:f><c:strCache>"
    '<c:ptCount val="1"/><c:pt idx="0"><c:v>Loja A e Meta</c:v></c:pt></c:strCache></c:strRef></c:tx>'
    "<c:cat><c:strRef><c:f>'Vendas 2026'!\$A\$2:\$A\$4</c:f></c:strRef></c:cat>"
    "<c:val><c:numRef><c:f>='Vendas 2026'!\$C\$2:\$C\$4</c:f></c:numRef></c:val></c:ser>"
    '<c:ser><c:idx val="1"/><c:order val="1"/>'
    '<c:val><c:numLit><c:formatCode>General</c:formatCode><c:ptCount val="1"/>'
    '<c:pt idx="0"><c:v>5</c:v></c:pt></c:numLit></c:val></c:ser>'
    '</c:pie3DChart></c:plotArea><c:plotVisOnly val="1"/></c:chart></c:chartSpace>';

const _radarChart =
    '<c:chartSpace xmlns:c="$_c"><c:chart><c:plotArea><c:layout/>'
    '<c:radarChart><c:radarStyle val="marker"/>'
    '<c:ser><c:idx val="0"/><c:order val="0"/><c:val><c:numRef>'
    "<c:f>'Vendas 2026'!\$B\$2:\$B\$4</c:f></c:numRef></c:val></c:ser>"
    '<c:axId val="1"/><c:axId val="2"/></c:radarChart>'
    '</c:plotArea></c:chart></c:chartSpace>';

/// Excel 365 in Portuguese: a column chart, a 3D pie in a one-cell anchor,
/// and what Voges Tables leaves out: a broken chart part, a radar chart, a
/// missing part, a picture, a chart of the newer `chartEx` kind and an
/// absolute anchor.
Uint8List excelChartWorkbook({String? drawing}) => workbookWithSheet(
  _excelChartSheet,
  name: 'Vendas 2026',
  parts: {
    'xl/_rels/workbook.xml.rels':
        '<Relationships xmlns="$_pkgRel">'
        '<Relationship Id="rId1" Type="$_rel/worksheet" Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" Type="$_rel/sharedStrings" Target="sharedStrings.xml"/>'
        '</Relationships>',
    'xl/sharedStrings.xml': _excelSharedStrings,
    'xl/worksheets/_rels/sheet1.xml.rels':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="$_pkgRel">'
        '<Relationship Id="rId1" Type="$_rel/printerSettings" '
        'Target="../printerSettings/printerSettings1.bin"/>'
        '<Relationship Id="rId2" Type="$_rel/drawing" Target="../drawings/drawing1.xml"/>'
        '</Relationships>',
    'xl/drawings/drawing1.xml': drawing ?? _excelDrawing,
    'xl/drawings/_rels/drawing1.xml.rels':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="$_pkgRel">'
        '<Relationship Id="rId1" Type="$_rel/chart" Target="../charts/chart1.xml"/>'
        '<Relationship Id="rId2" Type="$_rel/chart" Target="/xl/charts/chart2.xml"/>'
        '<Relationship Id="rId3" Type="$_rel/chart" Target="../charts/chart3.xml"/>'
        '<Relationship Id="rId4" Type="$_rel/chart" Target="../charts/chart4.xml"/>'
        '<Relationship Id="rId5" Type="$_rel/image" Target="../media/image1.png"/>'
        '<Relationship Id="rId6" Type="$_rel/chart" Target="../charts/chart9.xml"/>'
        '<Relationship Id="rId7" '
        'Type="http://schemas.microsoft.com/office/2014/relationships/chartEx" '
        'Target="../charts/chartEx1.xml"/>'
        '</Relationships>',
    'xl/charts/chart1.xml': _excelColumnChart,
    'xl/charts/chart2.xml': _excelPieChart,
    'xl/charts/chart3.xml':
        '<c:chartSpace xmlns:c="$_c"><c:chart><c:plotArea><c:barChart <c:ser>',
    'xl/charts/chart4.xml': _radarChart,
    'xl/charts/chartEx1.xml':
        '<cx:chartSpace xmlns:cx="http://schemas.microsoft.com/office/drawing/2014/chartex"/>',
  },
);
