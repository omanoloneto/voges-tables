import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../workbook/workbook_controller.dart';

/// The tabs of the sheets at the bottom, with a button to add one. A double
/// click renames; the right click opens rename and delete.
class SheetTabs extends StatelessWidget {
  const SheetTabs({
    required this.controller,
    required this.onRename,
    required this.onDelete,
    super.key,
  });

  final WorkbookController controller;
  final ValueChanged<int> onRename;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final sheets = controller.workbook.sheets;
    return Container(
      height: 34,
      color: scheme.surfaceContainerLow,
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.addSheet,
            iconSize: 18,
            onPressed: () =>
                controller.addSheet(l10n.sheetName(sheets.length + 1)),
            icon: const Icon(Icons.add),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sheets.length,
              itemBuilder: (context, index) {
                final active = index == controller.activeSheet;
                return GestureDetector(
                  onDoubleTap: () => onRename(index),
                  onSecondaryTapDown: (details) =>
                      _menu(context, details.globalPosition, index),
                  child: InkWell(
                    onTap: () => controller.showSheet(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? scheme.surface : null,
                        border: Border(
                          bottom: BorderSide(
                            color: active
                                ? const Color(0xFF1D6B3E)
                                : Colors.transparent,
                            width: 3,
                          ),
                          right: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                      child: Text(
                        sheets[index].name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: active
                              ? const Color(0xFF1D6B3E)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _menu(BuildContext context, Offset position, int index) async {
    final l10n = context.l10n;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(value: 'rename', child: Text(l10n.renameSheet)),
        PopupMenuItem(
          value: 'delete',
          enabled: controller.workbook.sheets.length > 1,
          child: Text(l10n.deleteSheet),
        ),
      ],
    );
    if (choice == 'rename') onRename(index);
    if (choice == 'delete') onDelete(index);
  }
}
