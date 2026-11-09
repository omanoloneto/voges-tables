import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../workbook/workbook_controller.dart';

enum UnsavedChoice { save, discard, cancel }

Future<UnsavedChoice> askToSave(BuildContext context, String name) async {
  final choice = await showDialog<UnsavedChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.saveChangesTitle),
      content: Text(context.l10n.saveChangesMessage(name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, UnsavedChoice.cancel),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, UnsavedChoice.discard),
          child: Text(context.l10n.dontSave),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context, UnsavedChoice.save),
          child: Text(context.l10n.save),
        ),
      ],
    ),
  );
  return choice ?? UnsavedChoice.cancel;
}

/// The new name of a sheet; null if canceled.
Future<String?> askSheetName(BuildContext context, String current) {
  final text = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final valid = WorkbookController.isValidSheetName(text.text.trim());
        void done() => Navigator.pop(context, text.text.trim());
        return AlertDialog(
          title: Text(context.l10n.renameSheet),
          content: TextField(
            controller: text,
            autofocus: true,
            maxLength: 31,
            onChanged: (_) => setState(() {}),
            onSubmitted: valid ? (_) => done() : null,
            decoration: InputDecoration(
              errorText: valid ? null : context.l10n.invalidSheetName,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: valid ? done : null,
              child: Text(context.l10n.apply),
            ),
          ],
        );
      },
    ),
  ).whenComplete(text.dispose);
}

Future<bool> confirmDeleteSheet(BuildContext context, String name) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.deleteSheet),
      content: Text(context.l10n.deleteSheetMessage(name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.deleteSheet),
        ),
      ],
    ),
  );
  return yes ?? false;
}

Future<bool> confirmMergeClearsData(BuildContext context) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.mergeCenter),
      content: Text(context.l10n.mergeClearsData),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.mergeAction),
        ),
      ],
    ),
  );
  return yes ?? false;
}
