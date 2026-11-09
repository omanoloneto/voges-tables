import 'dart:math' as math;

import '../sheet/cell_address.dart';
import '../sheet/cell_value.dart';
import '../sheet/workbook.dart';
import 'ast.dart';
import 'cell_source.dart';
import 'dependency_graph.dart';
import 'evaluator.dart';
import 'functions/registry.dart';
import 'locale.dart';
import 'parser.dart';

class _Formula {
  _Formula(this.sheet, this.address, this.expr);
  final int sheet;
  final CellAddress address;
  final Expr expr;
}

/// Keeps every formula of a [Workbook] calculated. After [setCell] only the
/// cells that depend on the edited one are evaluated again.
class Calculator {
  Calculator(
    this.workbook, {
    FormulaLocale locale = FormulaLocale.en,
    DateTime Function()? clock,
    math.Random? random,
  }) : _locale = locale,
       _clock = clock,
       _random = random ?? math.Random() {
    _evaluator = _newEvaluator();
    _rebuild();
  }

  final Workbook workbook;
  final DateTime Function()? _clock;
  final math.Random _random;
  late Evaluator _evaluator;
  FormulaLocale _locale;

  final _formulas = <CellKey, _Formula>{};
  final _values = <CellKey, CellValue>{};
  final _volatile = <CellKey>{};
  final _graph = DependencyGraph();
  final _corners = <CellAddress?>[];

  /// How many formulas the last recalculation evaluated.
  int get lastEvaluationCount => _evaluationCount;
  int _evaluationCount = 0;

  /// Text results such as `=1.5&""` and text-to-number conversions follow
  /// the interface language, as in Excel.
  FormulaLocale get locale => _locale;
  set locale(FormulaLocale value) {
    if (value == _locale) return;
    _locale = value;
    _evaluator = _newEvaluator();
    _recalculate(_formulas.keys.toList());
  }

  Evaluator _newEvaluator() =>
      Evaluator(_Source(this), locale: _locale, clock: _clock, random: _random);

  CellValue valueAt(int sheetIndex, CellAddress address) {
    if (sheetIndex < 0 || sheetIndex >= workbook.sheets.length) {
      return const EmptyValue();
    }
    final computed = _values[cellKey(sheetIndex, address)];
    if (computed != null) return computed;
    final cell = workbook.sheets[sheetIndex].cells[address];
    if (cell == null || cell.isFormula) return const EmptyValue();
    return cell.constant;
  }

  void setCell(int sheetIndex, CellAddress address, Cell cell) {
    if (sheetIndex < 0 || sheetIndex >= workbook.sheets.length) return;
    final sheet = workbook.sheets[sheetIndex];
    final old = sheet.cellAt(address);
    sheet.setCell(address, cell);
    if (old.input == cell.input && old.constant == cell.constant) return;
    final key = cellKey(sheetIndex, address);
    _unregister(key);
    if (cell.isFormula) _register(sheetIndex, address, cell.input);
    _grow(sheetIndex, address);
    _recalculate([key, ..._volatile]);
  }

  /// Reads every formula again from the workbook and evaluates them all.
  void recalculateAll() => _rebuild();

  /// Call after adding, removing, moving or renaming sheets: references by
  /// sheet name are resolved again.
  void sheetsChanged() => _rebuild();

  void _rebuild() {
    _formulas.clear();
    _values.clear();
    _volatile.clear();
    _graph.clear();
    _corners.clear();
    for (var s = 0; s < workbook.sheets.length; s++) {
      _corners.add(null);
      workbook.sheets[s].cells.forEach((address, cell) {
        _grow(s, address);
        if (cell.isFormula) _register(s, address, cell.input);
      });
    }
    _recalculate(_formulas.keys.toList());
  }

  void _grow(int sheet, CellAddress address) {
    final corner = _corners[sheet];
    if (corner == null) {
      _corners[sheet] = address;
    } else if (address.column > corner.column || address.row > corner.row) {
      _corners[sheet] = CellAddress(
        math.max(corner.column, address.column),
        math.max(corner.row, address.row),
      );
    }
  }

  void _register(int sheet, CellAddress address, String input) {
    final expr = parseFormula(input);
    final key = cellKey(sheet, address);
    _formulas[key] = _Formula(sheet, address, expr);
    final precedents = <(int, CellRange)>[];
    for (final node in expr.nodes) {
      if (node is ReferenceExpr) {
        final name = node.sheet;
        final target = name == null ? sheet : workbook.indexOf(name);
        if (target >= 0) precedents.add((target, node.range));
      } else if (node is CallExpr &&
          (functionRegistry[node.name]?.volatile ?? false)) {
        _volatile.add(key);
      }
    }
    _graph.add(key, precedents);
  }

  void _unregister(CellKey key) {
    _values.remove(key);
    _volatile.remove(key);
    if (_formulas.remove(key) != null) _graph.remove(key);
  }

  /// Evaluates [roots] and everything that depends on them, each formula
  /// after the ones it reads; formulas in a cycle get `#CIRC!`.
  void _recalculate(List<CellKey> roots) {
    _evaluationCount = 0;
    final order = <CellKey>[];
    final inDegree = <CellKey, int>{};
    for (final root in roots) {
      if (inDegree.containsKey(root)) continue;
      inDegree[root] = 0;
      order.add(root);
    }
    final edges = <CellKey, List<CellKey>>{};
    for (var i = 0; i < order.length; i++) {
      final dependents = _graph.dependentsOf(order[i]);
      if (dependents.isEmpty) continue;
      edges[order[i]] = dependents.toList();
      for (final dependent in dependents) {
        final degree = inDegree[dependent];
        if (degree == null) order.add(dependent);
        inDegree[dependent] = (degree ?? 0) + 1;
      }
    }
    final pending = _evaluateInOrder(order.toSet(), edges, inDegree);
    if (pending.isEmpty) return;
    final cyclic = _cyclicNodes(pending, edges);
    for (final key in cyclic) {
      _values[key] = const ErrorValue(CellError.circular);
    }
    final rest = pending.difference(cyclic);
    final restDegree = {for (final key in rest) key: 0};
    for (final key in rest) {
      for (final dependent in edges[key] ?? const <CellKey>[]) {
        if (rest.contains(dependent)) {
          restDegree[dependent] = restDegree[dependent]! + 1;
        }
      }
    }
    _evaluateInOrder(rest, edges, restDegree);
  }

  /// Kahn's algorithm over [nodes]; returns the ones it could not reach
  /// because they sit in or after a cycle.
  Set<CellKey> _evaluateInOrder(
    Set<CellKey> nodes,
    Map<CellKey, List<CellKey>> edges,
    Map<CellKey, int> inDegree,
  ) {
    final ready = [
      for (final key in nodes)
        if (inDegree[key] == 0) key,
    ];
    final done = <CellKey>{};
    while (ready.isNotEmpty) {
      final key = ready.removeLast();
      done.add(key);
      _evaluate(key);
      for (final dependent in edges[key] ?? const <CellKey>[]) {
        if (!nodes.contains(dependent)) continue;
        final degree = inDegree[dependent]! - 1;
        inDegree[dependent] = degree;
        if (degree == 0) ready.add(dependent);
      }
    }
    return nodes.difference(done);
  }

  void _evaluate(CellKey key) {
    final formula = _formulas[key];
    if (formula == null) return;
    _values[key] = _evaluator.evaluateFormula(
      formula.expr,
      formula.sheet,
      formula.address,
    );
    _evaluationCount++;
  }

  /// Members of strongly connected components that form a cycle (Tarjan,
  /// iterative so long chains do not overflow the stack).
  Set<CellKey> _cyclicNodes(
    Set<CellKey> nodes,
    Map<CellKey, List<CellKey>> edges,
  ) {
    var counter = 0;
    final index = <CellKey, int>{};
    final low = <CellKey, int>{};
    final stack = <CellKey>[];
    final onStack = <CellKey>{};
    final cyclic = <CellKey>{};
    for (final start in nodes) {
      if (index.containsKey(start)) continue;
      index[start] = low[start] = counter++;
      stack.add(start);
      onStack.add(start);
      final work = <(CellKey, int)>[(start, 0)];
      while (work.isNotEmpty) {
        final (node, next) = work.last;
        final targets = edges[node] ?? const <CellKey>[];
        if (next < targets.length) {
          work[work.length - 1] = (node, next + 1);
          final target = targets[next];
          if (!nodes.contains(target)) continue;
          if (!index.containsKey(target)) {
            index[target] = low[target] = counter++;
            stack.add(target);
            onStack.add(target);
            work.add((target, 0));
          } else if (onStack.contains(target)) {
            low[node] = math.min(low[node]!, index[target]!);
          }
          continue;
        }
        work.removeLast();
        if (work.isNotEmpty) {
          final parent = work.last.$1;
          low[parent] = math.min(low[parent]!, low[node]!);
        }
        if (low[node] != index[node]) continue;
        final component = <CellKey>[];
        CellKey member;
        do {
          member = stack.removeLast();
          onStack.remove(member);
          component.add(member);
        } while (member != node);
        if (component.length > 1 || targets.contains(node)) {
          cyclic.addAll(component);
        }
      }
    }
    return cyclic;
  }
}

class _Source implements CellSource {
  _Source(this._calculator);
  final Calculator _calculator;

  Workbook get _workbook => _calculator.workbook;

  @override
  int sheetIndex(String name) => _workbook.indexOf(name);

  @override
  CellValue valueAt(int sheet, CellAddress address) =>
      _calculator.valueAt(sheet, address);

  @override
  Iterable<CellAddress> storedAddresses(int sheet) =>
      _workbook.sheets[sheet].cells.keys;

  @override
  int storedCount(int sheet) => _workbook.sheets[sheet].cells.length;

  @override
  CellAddress? usedCorner(int sheet) =>
      sheet < _calculator._corners.length ? _calculator._corners[sheet] : null;
}
