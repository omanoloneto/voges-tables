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
