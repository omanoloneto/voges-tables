import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../sheet/chart.dart';

IconData chartKindIcon(ChartKind kind) => switch (kind) {
  ChartKind.column => Icons.bar_chart,
  ChartKind.bar => Icons.align_horizontal_left,
  ChartKind.line => Icons.show_chart,
  ChartKind.area => Icons.area_chart_outlined,
  ChartKind.pie => Icons.pie_chart_outline,
  ChartKind.scatter => Icons.scatter_plot_outlined,
};

String chartKindName(AppLocalizations l10n, ChartKind kind) => switch (kind) {
  ChartKind.column => l10n.chartColumn,
  ChartKind.bar => l10n.chartBar,
  ChartKind.line => l10n.chartLine,
  ChartKind.area => l10n.chartArea,
  ChartKind.pie => l10n.chartPie,
  ChartKind.scatter => l10n.chartScatter,
};
