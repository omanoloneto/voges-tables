import 'package:flutter/material.dart';

import '../formula/format.dart';
import '../formula/locale.dart';
import '../l10n/l10n.dart';
import '../sheet/cell_style.dart';
import '../sheet/cell_value.dart';
import '../workbook/workbook_controller.dart';

const minZoom = 0.25, maxZoom = 4.0;

double clampZoom(double zoom) => zoom.clamp(minZoom, maxZoom);

/// Sum, average and count of the selection, as spreadsheets show them, and
/// the zoom.
class StatusBar extends StatelessWidget {
  const StatusBar({
    required this.controller,
    required this.locale,
    required this.zoom,
    required this.onZoom,
    this.trailing,
    super.key,
  });

  final WorkbookController controller;
  final FormulaLocale locale;
  final double zoom;
  final ValueChanged<double> onZoom;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final style = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    String number(double value) => formatValue(
      NumberValue(value),
      const NumberFormat(NumberKind.general),
      locale,
    );
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final stats = controller.stats;
        return Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: scheme.surfaceContainer,
          child: Row(
            children: [
              if (stats != null) ...[
                if (stats.average case final average?) ...[
                  Text('${l10n.average}: ${number(average)}', style: style),
                  const SizedBox(width: 18),
                ],
                Text('${l10n.count}: ${stats.count}', style: style),
                if (stats.numbers > 0) ...[
                  const SizedBox(width: 18),
                  Text('${l10n.sum}: ${number(stats.sum)}', style: style),
                ],
              ],
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: trailing,
                ),
              ),
              IconButton(
                tooltip: l10n.zoomOut,
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed: () => onZoom(clampZoom(zoom - 0.1)),
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 120,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                  ),
                  child: Slider(
                    value: clampZoom(zoom),
                    min: minZoom,
                    max: maxZoom,
                    onChanged: onZoom,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.zoomIn,
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed: () => onZoom(clampZoom(zoom + 0.1)),
                icon: const Icon(Icons.add),
              ),
              TextButton(
                onPressed: () => onZoom(1),
                child: Text('${(zoom * 100).round()}%', style: style),
              ),
            ],
          ),
        );
      },
    );
  }
}
