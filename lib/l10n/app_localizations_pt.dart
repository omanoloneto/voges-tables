// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get addSheet => 'Adicionar planilha';

  @override
  String get alignBottom => 'Alinhar embaixo';

  @override
  String get alignCenter => 'Centralizar';

  @override
  String get alignLeft => 'Alinhar à esquerda';

  @override
  String get alignMiddle => 'Alinhar no meio';

  @override
  String get alignRight => 'Alinhar à direita';

  @override
  String get alignTop => 'Alinhar em cima';

  @override
  String get alignmentGroup => 'Alinhamento';

  @override
  String get allBorders => 'Todas as bordas';

  @override
  String get apply => 'Aplicar';

  @override
  String get autoSum => 'AutoSoma';

  @override
  String get autoSumHint => 'Soma dos números acima ou à esquerda';

  @override
  String get automaticColor => 'Automático';

  @override
  String get average => 'Média';

  @override
  String get bold => 'Negrito';

  @override
  String get bottomBorder => 'Borda inferior';

  @override
  String get cancel => 'Cancelar';

  @override
  String get cellsGroup => 'Células';

  @override
  String get clearContents => 'Limpar conteúdo';

  @override
  String get clearFormats => 'Limpar formatos';

  @override
  String get clipboardGroup => 'Área de transferência';

  @override
  String get close => 'Fechar';

  @override
  String get copy => 'Copiar';

  @override
  String get count => 'Contagem';

  @override
  String get csvOnlyActiveSheet =>
      'O CSV guarda só os valores da planilha aberta.';

  @override
  String get cut => 'Recortar';

  @override
  String get dataGroup => 'Dados';

  @override
  String get deleteSheet => 'Excluir planilha';

  @override
  String get dontSave => 'Não salvar';

  @override
  String get fewerDecimals => 'Menos casas decimais';

  @override
  String get fileMenu => 'Arquivo';

  @override
  String get fillColor => 'Cor de preenchimento';

  @override
  String get fontGroup => 'Fonte';

  @override
  String get fontSize => 'Tamanho da fonte';

  @override
  String get formatCurrency => 'Moeda';

  @override
  String get formatDate => 'Data';

  @override
  String get formatDateTime => 'Data e hora';

  @override
  String get formatGeneral => 'Geral';

  @override
  String get formatNumber => 'Número';

  @override
  String get formatPercent => 'Porcentagem';

  @override
  String get formatText => 'Texto';

  @override
  String get formatTime => 'Hora';

  @override
  String get formulaBarHint =>
      'Digite um valor ou uma fórmula, como =SOMA(A1:A5)';

  @override
  String get freezePanes => 'Congelar acima e à esquerda da célula';

  @override
  String get freezeTopRow => 'Congelar primeira linha';

  @override
  String get invalidSheetName => 'Até 31 caracteres, sem : \\ / ? * [ ]';

  @override
  String get italic => 'Itálico';

  @override
  String get language => 'Idioma';

  @override
  String get maximize => 'Maximizar';

  @override
  String get minimize => 'Minimizar';

  @override
  String get moreDecimals => 'Mais casas decimais';

  @override
  String get newFile => 'Novo';

  @override
  String get noBorders => 'Sem bordas';

  @override
  String get noFill => 'Sem preenchimento';

  @override
  String get nothingToPaste => 'Nada para colar.';

  @override
  String get numberFormat => 'Formato de número';

  @override
  String get numberGroup => 'Número';

  @override
  String get openFailed => 'Não foi possível abrir este arquivo.';

  @override
  String get openFile => 'Abrir';

  @override
  String get openFileTitle => 'Abrir planilha';

  @override
  String get paste => 'Colar';

  @override
  String get redo => 'Refazer';

  @override
  String get renameSheet => 'Renomear planilha';

  @override
  String get restore => 'Restaurar';

  @override
  String get save => 'Salvar';

  @override
  String get saveAs => 'Salvar como';

  @override
  String get saveChangesTitle => 'Salvar as alterações?';

  @override
  String get saveFailed => 'Não foi possível salvar o arquivo.';

  @override
  String get saveFileTitle => 'Salvar planilha';

  @override
  String get sheetNameTaken => 'Outra planilha já tem esse nome.';

  @override
  String get sortAscending => 'Classificar de A a Z';

  @override
  String get sortDescending => 'Classificar de Z a A';

  @override
  String get strikethrough => 'Tachado';

  @override
  String get sum => 'Soma';

  @override
  String get systemLanguage => 'Idioma do sistema';

  @override
  String get textColor => 'Cor da fonte';

  @override
  String get underline => 'Sublinhado';

  @override
  String get undo => 'Desfazer';

  @override
  String get unfreeze => 'Descongelar';

  @override
  String get unsavedChanges => 'Alterações não salvas';

  @override
  String get unsupportedFormat =>
      'Este tipo de arquivo ainda não abre. Salve como .xlsx ou .csv no outro programa.';

  @override
  String get untitled => 'Sem título';

  @override
  String get wrapText => 'Quebrar texto';

  @override
  String get zoomIn => 'Aumentar zoom';

  @override
  String get zoomOut => 'Diminuir zoom';

  @override
  String deleteSheetMessage(String name) {
    return 'Excluir a planilha \"$name\"? Isso não pode ser desfeito.';
  }

  @override
  String saveAsFormat(String format) {
    return 'Salvar como $format';
  }

  @override
  String saveChangesMessage(String name) {
    return 'Deseja salvar as alterações em \"$name\"?';
  }

  @override
  String sheetName(int number) {
    return 'Planilha$number';
  }

  @override
  String get insertCells => 'Inserir';

  @override
  String get deleteCells => 'Excluir';

  @override
  String get insertRows => 'Inserir linhas';

  @override
  String get insertColumns => 'Inserir colunas';

  @override
  String get deleteRows => 'Excluir linhas';

  @override
  String get deleteColumns => 'Excluir colunas';

  @override
  String get insertNoRoom =>
      'Não há espaço: as últimas linhas ou colunas da planilha têm dados.';
}
