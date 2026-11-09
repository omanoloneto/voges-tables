// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get addSheet => 'Agregar hoja';

  @override
  String get alignBottom => 'Alinear abajo';

  @override
  String get alignCenter => 'Centrar';

  @override
  String get alignLeft => 'Alinear a la izquierda';

  @override
  String get alignMiddle => 'Alinear en el medio';

  @override
  String get alignRight => 'Alinear a la derecha';

  @override
  String get alignTop => 'Alinear arriba';

  @override
  String get alignmentGroup => 'Alineación';

  @override
  String get allBorders => 'Todos los bordes';

  @override
  String get apply => 'Aplicar';

  @override
  String get autoSum => 'Autosuma';

  @override
  String get autoSumHint => 'Suma de los números de arriba o de la izquierda';

  @override
  String get automaticColor => 'Automático';

  @override
  String get average => 'Promedio';

  @override
  String get bold => 'Negrita';

  @override
  String get bottomBorder => 'Borde inferior';

  @override
  String get cancel => 'Cancelar';

  @override
  String get cellsGroup => 'Celdas';

  @override
  String get clearContents => 'Borrar contenido';

  @override
  String get clearFormats => 'Borrar formatos';

  @override
  String get clipboardGroup => 'Portapapeles';

  @override
  String get close => 'Cerrar';

  @override
  String get copy => 'Copiar';

  @override
  String get count => 'Recuento';

  @override
  String get csvOnlyActiveSheet =>
      'El CSV guarda solo los valores de la hoja abierta.';

  @override
  String get cut => 'Cortar';

  @override
  String get dataGroup => 'Datos';

  @override
  String get deleteSheet => 'Eliminar hoja';

  @override
  String get dontSave => 'No guardar';

  @override
  String get fewerDecimals => 'Menos decimales';

  @override
  String get fileMenu => 'Archivo';

  @override
  String get fillColor => 'Color de relleno';

  @override
  String get fontGroup => 'Fuente';

  @override
  String get fontSize => 'Tamaño de fuente';

  @override
  String get formatCurrency => 'Moneda';

  @override
  String get formatDate => 'Fecha';

  @override
  String get formatDateTime => 'Fecha y hora';

  @override
  String get formatGeneral => 'General';

  @override
  String get formatNumber => 'Número';

  @override
  String get formatPercent => 'Porcentaje';

  @override
  String get formatText => 'Texto';

  @override
  String get formatTime => 'Hora';

  @override
  String get formulaBarHint =>
      'Escriba un valor o una fórmula, como =SUMA(A1:A5)';

  @override
  String get freezePanes => 'Inmovilizar arriba y a la izquierda de la celda';

  @override
  String get freezeTopRow => 'Inmovilizar fila superior';

  @override
  String get invalidSheetName => 'Hasta 31 caracteres, sin : \\ / ? * [ ]';

  @override
  String get italic => 'Cursiva';

  @override
  String get language => 'Idioma';

  @override
  String get maximize => 'Maximizar';

  @override
  String get minimize => 'Minimizar';

  @override
  String get moreDecimals => 'Más decimales';

  @override
  String get newFile => 'Nuevo';

  @override
  String get noBorders => 'Sin bordes';

  @override
  String get noFill => 'Sin relleno';

  @override
  String get nothingToPaste => 'Nada para pegar.';

  @override
  String get numberFormat => 'Formato de número';

  @override
  String get numberGroup => 'Número';

  @override
  String get openFailed => 'No se pudo abrir este archivo.';

  @override
  String get openFile => 'Abrir';

  @override
  String get openFileTitle => 'Abrir hoja de cálculo';

  @override
  String get paste => 'Pegar';

  @override
  String get redo => 'Rehacer';

  @override
  String get renameSheet => 'Cambiar nombre de la hoja';

  @override
  String get restore => 'Restaurar';

  @override
  String get save => 'Guardar';

  @override
  String get saveAs => 'Guardar como';

  @override
  String get saveChangesTitle => '¿Guardar los cambios?';

  @override
  String get saveFailed => 'No se pudo guardar el archivo.';

  @override
  String get saveFileTitle => 'Guardar hoja de cálculo';

  @override
  String get sheetNameTaken => 'Otra hoja ya tiene este nombre.';

  @override
  String get sortAscending => 'Ordenar de A a Z';

  @override
  String get sortDescending => 'Ordenar de Z a A';

  @override
  String get strikethrough => 'Tachado';

  @override
  String get sum => 'Suma';

  @override
  String get systemLanguage => 'Idioma del sistema';

  @override
  String get textColor => 'Color de fuente';

  @override
  String get underline => 'Subrayado';

  @override
  String get undo => 'Deshacer';

  @override
  String get unfreeze => 'Movilizar';

  @override
  String get unsavedChanges => 'Cambios sin guardar';

  @override
  String get unsupportedFormat =>
      'Este tipo de archivo aún no se abre. Guárdelo como .xlsx o .csv en el otro programa.';

  @override
  String get untitled => 'Sin título';

  @override
  String get wrapText => 'Ajustar texto';

  @override
  String get zoomIn => 'Acercar';

  @override
  String get zoomOut => 'Alejar';

  @override
  String deleteSheetMessage(String name) {
    return '¿Eliminar la hoja \"$name\"? No se puede deshacer.';
  }

  @override
  String saveAsFormat(String format) {
    return 'Guardar como $format';
  }

  @override
  String saveChangesMessage(String name) {
    return '¿Desea guardar los cambios en \"$name\"?';
  }

  @override
  String sheetName(int number) {
    return 'Hoja$number';
  }
}
