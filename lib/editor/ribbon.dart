import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../sheet/cell_style.dart';
import '../shell/platform.dart';
import '../shell/ribbon_controls.dart';
import '../shell/ribbon_style.dart';
import '../workbook/workbook_controller.dart';

class RibbonActions {
  const RibbonActions({
    required this.copy,
    required this.cut,
    required this.paste,
    required this.autoSum,
  });

  final VoidCallback copy;
  final VoidCallback cut;
  final VoidCallback paste;
  final VoidCallback autoSum;
}

/// Colors offered for text and fill, the classic office palette.
const paletteColors = [
  0xFF000000,
  0xFF434343,
  0xFF666666,
  0xFF999999,
  0xFFCCCCCC,
  0xFFFFFFFF,
  0xFFC00000,
  0xFFFF0000,
  0xFFFFC000,
  0xFFFFFF00,
  0xFF92D050,
  0xFF00B050,
  0xFF00B0F0,
  0xFF0070C0,
  0xFF002060,
  0xFF7030A0,
  0xFFF4CCCC,
  0xFFFCE5CD,
  0xFFFFF2CC,
  0xFFD9EAD3,
  0xFFD0E0E3,
  0xFFCFE2F3,
  0xFFD9D2E9,
  0xFFEAD1DC,
];

const _fontSizes = [
  8.0,
  9.0,
  10.0,
  11.0,
  12.0,
  14.0,
  16.0,
  18.0,
  20.0,
  24.0,
  28.0,
  36.0,
  48.0,
];

/// The tools of the selected cells, in one row.
class Ribbon extends StatelessWidget {
  const Ribbon({required this.controller, required this.actions, super.key});

  final WorkbookController controller;
  final RibbonActions actions;

  CellStyle get style => controller.activeStyle;

  void _style(CellStyle Function(CellStyle style) update) =>
      controller.applyStyle(update);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        decoration: BoxDecoration(
          color: RibbonColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: RibbonColors.panelBorder),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RibbonGroup(label: l10n.clipboardGroup, child: _clipboard(l10n)),
              const RibbonGroupDivider(),
              RibbonGroup(label: l10n.fontGroup, child: _font(l10n)),
              const RibbonGroupDivider(),
              RibbonGroup(label: l10n.alignmentGroup, child: _alignment(l10n)),
              const RibbonGroupDivider(),
              RibbonGroup(label: l10n.numberGroup, child: _number(l10n)),
              const RibbonGroupDivider(),
              RibbonGroup(label: l10n.cellsGroup, child: _cells(l10n)),
              const RibbonGroupDivider(),
              RibbonGroup(label: l10n.dataGroup, child: _data(l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clipboard(AppLocalizations l10n) => Row(
    children: [
      RibbonBigButton(
        icon: Icons.content_paste,
        label: l10n.paste,
        tooltip: '${l10n.paste} (${shortcutLabel('V')})',
        onPressed: actions.paste,
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RibbonIconButton(
            icon: Icons.content_cut,
            tooltip: '${l10n.cut} (${shortcutLabel('X')})',
            onPressed: actions.cut,
          ),
          RibbonIconButton(
            icon: Icons.content_copy,
            tooltip: '${l10n.copy} (${shortcutLabel('C')})',
            onPressed: actions.copy,
          ),
        ],
      ),
    ],
  );

  Widget _font(AppLocalizations l10n) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RibbonDropdown<double>(
        tooltip: l10n.fontSize,
        label: _number2(style.fontSize),
        width: 72,
        options: [
          for (final size in _fontSizes) RibbonOption(size, _number2(size)),
        ],
        selected: style.fontSize,
        onSelected: (size) => _style((s) => s.copyWith(fontSize: size)),
      ),
      const SizedBox(height: 2),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RibbonIconButton(
            icon: Icons.format_bold,
            tooltip: '${l10n.bold} (${shortcutLabel('B')})',
            selected: style.bold,
            onPressed: () => _style((s) => s.copyWith(bold: !style.bold)),
          ),
          RibbonIconButton(
            icon: Icons.format_italic,
            tooltip: '${l10n.italic} (${shortcutLabel('I')})',
            selected: style.italic,
            onPressed: () => _style((s) => s.copyWith(italic: !style.italic)),
          ),
          RibbonIconButton(
            icon: Icons.format_underlined,
            tooltip: '${l10n.underline} (${shortcutLabel('U')})',
            selected: style.underline,
            onPressed: () =>
                _style((s) => s.copyWith(underline: !style.underline)),
          ),
          RibbonIconButton(
            icon: Icons.format_strikethrough,
            tooltip: l10n.strikethrough,
            selected: style.strike,
            onPressed: () => _style((s) => s.copyWith(strike: !style.strike)),
          ),
          _ColorButton(
            icon: Icons.format_color_text,
            tooltip: l10n.textColor,
            current: style.textColor,
            automatic: l10n.automaticColor,
            onPicked: (color) =>
                _style((s) => s.copyWith(textColor: () => color)),
          ),
          _ColorButton(
            icon: Icons.format_color_fill,
            tooltip: l10n.fillColor,
            current: style.fillColor,
            automatic: l10n.noFill,
            onPicked: (color) =>
                _style((s) => s.copyWith(fillColor: () => color)),
          ),
        ],
      ),
    ],
  );

  Widget _alignment(AppLocalizations l10n) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (align, icon, tip) in [
            (VerticalAlign.top, Icons.vertical_align_top, l10n.alignTop),
            (
              VerticalAlign.middle,
              Icons.vertical_align_center,
              l10n.alignMiddle,
            ),
            (
              VerticalAlign.bottom,
              Icons.vertical_align_bottom,
              l10n.alignBottom,
            ),
          ])
            RibbonIconButton(
              icon: icon,
              tooltip: tip,
              selected: style.vertical == align,
              onPressed: () => _style((s) => s.copyWith(vertical: align)),
            ),
          RibbonIconButton(
            icon: Icons.wrap_text,
            tooltip: l10n.wrapText,
            selected: style.wrap,
            onPressed: () => _style((s) => s.copyWith(wrap: !style.wrap)),
          ),
        ],
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (align, icon, tip) in [
            (HorizontalAlign.left, Icons.format_align_left, l10n.alignLeft),
            (
              HorizontalAlign.center,
              Icons.format_align_center,
              l10n.alignCenter,
            ),
            (HorizontalAlign.right, Icons.format_align_right, l10n.alignRight),
          ])
            RibbonIconButton(
              icon: icon,
              tooltip: tip,
              selected: style.horizontal == align,
              onPressed: () => _style(
                (s) => s.copyWith(
                  horizontal: s.horizontal == align
                      ? HorizontalAlign.general
                      : align,
                ),
              ),
            ),
          const SizedBox(width: 34),
        ],
      ),
    ],
  );

  Widget _number(AppLocalizations l10n) {
    final format = style.format;
    final names = {
      NumberKind.general: l10n.formatGeneral,
      NumberKind.number: l10n.formatNumber,
      NumberKind.currency: l10n.formatCurrency,
      NumberKind.percent: l10n.formatPercent,
      NumberKind.date: l10n.formatDate,
      NumberKind.time: l10n.formatTime,
      NumberKind.dateTime: l10n.formatDateTime,
      NumberKind.text: l10n.formatText,
    };
    final decimals =
        format.kind != NumberKind.general &&
        format.kind != NumberKind.text &&
        format.kind != NumberKind.date;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RibbonDropdown<NumberKind>(
          tooltip: l10n.numberFormat,
          label: names[format.kind]!,
          width: 130,
          options: [
            for (final entry in names.entries)
              RibbonOption(entry.key, entry.value),
          ],
          selected: format.kind,
          onSelected: (kind) => _style(
            (s) => s.copyWith(
              format: NumberFormat(
                kind,
                decimals: kind == NumberKind.percent ? 0 : 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RibbonIconButton(
              icon: Icons.attach_money,
              tooltip: l10n.formatCurrency,
              selected: format.kind == NumberKind.currency,
              onPressed: () => _style(
                (s) =>
                    s.copyWith(format: const NumberFormat(NumberKind.currency)),
              ),
            ),
            RibbonIconButton(
              icon: Icons.percent,
              tooltip: l10n.formatPercent,
              selected: format.kind == NumberKind.percent,
              onPressed: () => _style(
                (s) => s.copyWith(
                  format: const NumberFormat(NumberKind.percent, decimals: 0),
                ),
              ),
            ),
            RibbonIconButton(
              icon: Icons.add,
              tooltip: l10n.moreDecimals,
              onPressed: () =>
                  _style((s) => s.copyWith(format: _decimals(s.format, 1))),
              child: const Text(
                '.0+',
                style: TextStyle(
                  color: RibbonColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            RibbonIconButton(
              icon: Icons.remove,
              tooltip: l10n.fewerDecimals,
              onPressed: decimals || format.kind == NumberKind.general
                  ? () => _style(
                      (s) => s.copyWith(format: _decimals(s.format, -1)),
                    )
                  : null,
              child: Text(
                '.0−',
                style: TextStyle(
                  color: RibbonColors.text.withValues(
                    alpha: decimals || format.kind == NumberKind.general
                        ? 1
                        : 0.35,
                  ),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// General turns into a number with that many decimals, as in Excel.
  static NumberFormat _decimals(NumberFormat format, int step) {
    final base = format.kind == NumberKind.general
        ? const NumberFormat(NumberKind.number, decimals: 0, thousands: false)
        : format;
    return base.copyWith(decimals: (base.decimals + step).clamp(0, 10));
  }

  Widget _cells(AppLocalizations l10n) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RibbonIconButton(
            icon: Icons.border_all,
            tooltip: l10n.allBorders,
            onPressed: () =>
                _style((s) => s.copyWith(borders: CellBorders.all)),
          ),
          RibbonIconButton(
            icon: Icons.border_bottom,
            tooltip: l10n.bottomBorder,
            onPressed: () => _style(
              (s) => s.copyWith(
                borders: CellBorders(
                  top: s.borders.top,
                  left: s.borders.left,
                  right: s.borders.right,
                  bottom: true,
                ),
              ),
            ),
          ),
          RibbonIconButton(
            icon: Icons.border_clear,
            tooltip: l10n.noBorders,
            onPressed: () =>
                _style((s) => s.copyWith(borders: CellBorders.none)),
          ),
        ],
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RibbonIconButton(
            icon: Icons.backspace_outlined,
            tooltip: l10n.clearContents,
            onPressed: controller.clearContents,
          ),
          RibbonIconButton(
            icon: Icons.format_clear,
            tooltip: l10n.clearFormats,
            onPressed: controller.clearFormats,
          ),
          const SizedBox(width: 34),
        ],
      ),
    ],
  );

  Widget _data(AppLocalizations l10n) {
    final sheet = controller.sheet;
    final frozen = sheet.frozenRows > 0 || sheet.frozenColumns > 0;
    return Row(
      children: [
        RibbonBigButton(
          icon: Icons.functions,
          label: l10n.autoSum,
          tooltip: l10n.autoSumHint,
          onPressed: actions.autoSum,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RibbonIconButton(
                  icon: Icons.arrow_upward,
                  tooltip: l10n.sortAscending,
                  onPressed: () => controller.sortSelection(ascending: true),
                ),
                RibbonIconButton(
                  icon: Icons.arrow_downward,
                  tooltip: l10n.sortDescending,
                  onPressed: () => controller.sortSelection(ascending: false),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RibbonIconButton(
                  icon: Icons.table_rows_outlined,
                  tooltip: frozen ? l10n.unfreeze : l10n.freezeTopRow,
                  selected: sheet.frozenRows == 1 && sheet.frozenColumns == 0,
                  onPressed: () => frozen
                      ? controller.setFrozen(rows: 0, columns: 0)
                      : controller.setFrozen(rows: 1, columns: 0),
                ),
                RibbonIconButton(
                  icon: Icons.grid_on,
                  tooltip: frozen ? l10n.unfreeze : l10n.freezePanes,
                  selected:
                      frozen &&
                      !(sheet.frozenRows == 1 && sheet.frozenColumns == 0),
                  onPressed: () {
                    final active = controller.selection.active;
                    frozen
                        ? controller.setFrozen(rows: 0, columns: 0)
                        : controller.setFrozen(
                            rows: active.row,
                            columns: active.column,
                          );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static String _number2(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.icon,
    required this.tooltip,
    required this.current,
    required this.automatic,
    required this.onPicked,
  });

  final IconData icon;
  final String tooltip;
  final int? current;
  final String automatic;
  final ValueChanged<int?> onPicked;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: ribbonMenuStyle(),
      menuChildren: [
        MenuItemButton(
          style: ribbonMenuItemStyle(),
          onPressed: () => onPicked(null),
          child: Text(automatic),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 6 * 28,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final color in paletteColors)
                  InkWell(
                    onTap: () {
                      onPicked(color);
                      MenuController.maybeOf(context)?.close();
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(color),
                        border: Border.all(
                          color: color == current
                              ? RibbonColors.text
                              : const Color(0x55FFFFFF),
                          width: color == current ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, menu, _) => RibbonIconButton(
        icon: icon,
        tooltip: tooltip,
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17),
            Container(
              width: 18,
              height: 4,
              color: current == null ? Colors.transparent : Color(current!),
            ),
          ],
        ),
      ),
    );
  }
}
