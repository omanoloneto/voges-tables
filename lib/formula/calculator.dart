import 'dart:math' as math;

import '../sheet/cell_address.dart';
import '../sheet/cell_value.dart';
import '../sheet/structure.dart';
import '../sheet/workbook.dart';
import 'ast.dart';
import 'cell_source.dart';
import 'dependency_graph.dart';
import 'evaluator.dart';
import 'functions/registry.dart';
import 'locale.dart';
import 'parser.dart';
import 'references.dart';

class _Formula {
  _Formula(
    this.sheet,
    this.address,
    this.expr,
    this.references,
    this.positional,
  );
  final int sheet;
  final CellAddress address;
  final Expr expr;

  /// Every reference with the index of its sheet, -1 for an unknown sheet.
  final List<(int, CellRange)> references;

  /// Uses ROW or COLUMN, whose result depends on where things are.
  final bool positional;
}

const _positionalFunctions = {'ROW', 'COLUMN'};

/// What [Calculator.changeStructure] did, to undo it.
class StructureResult {
  StructureResult(this.rewritten, this.removed);

  /// The formulas whose text changed, by where they are now, with the text
  /// they had before.
  final Map<CellKey, String> rewritten;

  /// The deleted cells, where they were.
  final Map<CellAddress, Cell> removed;
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

  void setCell(int sheetIndex, CellAddress address, Cell cell) =>
      setCells({cellKey(sheetIndex, address): cell});

  /// Writes many cells and calculates what depends on them once, so pasting
  /// or filling thousands of cells does not walk the dependents per cell.
  void setCells(Map<CellKey, Cell> cells) {
    final roots = <CellKey>[];
    cells.forEach((key, cell) {
      final sheet = key.sheet, address = key.address;
      if (sheet < 0 || sheet >= workbook.sheets.length) return;
      final target = workbook.sheets[sheet];
      final old = target.cellAt(address);
      target.setCell(address, cell);
      if (old.input == cell.input && old.constant == cell.constant) return;
      _unregister(key);
      if (cell.isFormula) _register(sheet, address, cell.input);
      _grow(sheet, address);
      roots.add(key);
    });
    if (roots.isEmpty) return;
    _recalculate([...roots, ..._volatile]);
  }

  /// Inserts or deletes rows or columns: moves the cells of the sheet,
  /// rewrites every reference to them in the workbook and evaluates only the
  /// formulas whose result can change. Null when inserting would push
  /// filled cells off the sheet.
  StructureResult? changeStructure(StructureEdit edit) {
    final s = edit.sheet;
    if (s < 0 || s >= workbook.sheets.length) return null;
    final sheet = workbook.sheets[s];
    final rows = edit.axis == SheetAxis.rows;
    if (edit.isInsert) {
      final corner = sheet.usedRange?.last;
      final last = corner == null ? -1 : (rows ? corner.row : corner.column);
      if (edit.count >= edit.limit || last + edit.count >= edit.limit) {
        return null;
      }
    }
    final targetName = sheet.name.toLowerCase();
    final rewritten = <CellKey, String>{};
    final newTexts = <CellKey, String>{};
    final newExprs = <CellKey, Expr>{};
    final reevaluate = <CellKey>{};
    bool targets(String? name, int formulaSheet) =>
        name == null ? formulaSheet == s : name.toLowerCase() == targetName;

    for (final formula in _formulas.values) {
      final moves = formula.sheet == s;
      var touched = false, reshaped = false;
      for (final (target, range) in formula.references) {
        if (target != s) continue;
        final high = rows ? range.last.row : range.last.column;
        if (high < edit.at) continue;
        touched = true;
        if (!edit.translatesRange(range)) reshaped = true;
      }
      final newAddress = moves
          ? edit.moveCell(formula.address)
          : formula.address;
      if (newAddress == null) continue;
      final newKey = cellKey(formula.sheet, newAddress);
      if (reshaped ||
          (formula.positional && (touched || newAddress != formula.address))) {
        reevaluate.add(newKey);
      }
      if (!touched) continue;
      final input =
          workbook.sheets[formula.sheet].cells[formula.address]!.input;
      final text = adjustReferences(
        input,
        edit,
        targets: (name) => targets(name, formula.sheet),
      );
      if (identical(text, input)) continue;
      rewritten[newKey] = input;
      newTexts[newKey] = text;
      final expr = _moveExpr(
        formula.expr,
        edit,
        (name) => targets(name, formula.sheet),
      );
      if (expr != null) newExprs[newKey] = expr;
    }

    final removed = <CellAddress, Cell>{};
    final moved = <CellAddress, Cell>{};
    sheet.cells.forEach((address, cell) {
      final to = edit.moveCell(address);
      if (to == null) {
        removed[address] = cell;
      } else {
        moved[to] = cell;
      }
    });
    newTexts.forEach((key, text) {
      final target = key.sheet == s ? moved : workbook.sheets[key.sheet].cells;
      final cell = target[key.address]!;
      final updated = cell.copyWith(input: text);
      if (key.sheet == s) {
        moved[key.address] = updated;
      } else {
        workbook.sheets[key.sheet].setCell(key.address, updated);
      }
    });
    sheet.replaceCells(moved);

    final stale = <CellKey>[];
    final renamed = <CellKey, _Formula>{};
    for (final MapEntry(:key, value: formula) in _formulas.entries) {
      final newAddress = formula.sheet == s
          ? edit.moveCell(formula.address)
          : formula.address;
      final newKey = newAddress == null
          ? null
          : cellKey(formula.sheet, newAddress);
      final text = newKey == null ? null : newTexts[newKey];
      if (newKey == key && text == null) continue;
      stale.add(key);
      if (newKey == null) continue;
      final expr = newExprs[newKey];
      renamed[newKey] = text == null
          ? _Formula(
              formula.sheet,
              newAddress!,
              formula.expr,
              formula.references,
              formula.positional,
            )
          : expr != null
          ? _described(formula.sheet, newAddress!, expr)
          : _parsed(formula.sheet, newAddress!, text);
    }
    final relinkAll = stale.length * 4 > _formulas.length;
    if (relinkAll) _graph.clear();
    final values = <CellKey, CellValue>{};
    final volatile = <CellKey>{};
    for (final key in stale) {
      if (!relinkAll) _graph.remove(key);
      final value = _values.remove(key);
      final wasVolatile = _volatile.remove(key);
      _formulas.remove(key);
      final address = key.sheet == s ? edit.moveCell(key.address) : key.address;
      if (address == null) continue;
      final newKey = cellKey(key.sheet, address);
      if (value != null) values[newKey] = value;
      if (wasVolatile) volatile.add(newKey);
    }
    _values.addAll(values);
    _volatile.addAll(volatile);
    renamed.forEach((key, formula) => _formulas[key] = formula);
    if (relinkAll) {
      _formulas.forEach(_link);
    } else {
      renamed.forEach(_link);
    }
    _corners[s] = sheet.usedRange?.last;
    _recalculate([...reevaluate, ..._volatile]);
    return StructureResult(rewritten, removed);
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
    final key = cellKey(sheet, address);
    final formula = _parsed(sheet, address, input);
    _formulas[key] = formula;
    _link(key, formula);
  }

  _Formula _parsed(int sheet, CellAddress address, String input) =>
      _described(sheet, address, parseFormula(input));

  _Formula _described(int sheet, CellAddress address, Expr expr) {
    final references = <(int, CellRange)>[];
    var positional = false;
    void visit(Expr node) {
      switch (node) {
        case ReferenceExpr(sheet: final name, :final range):
          references.add((
            name == null ? sheet : workbook.indexOf(name),
            range,
          ));
        case UnaryExpr(:final operand):
          visit(operand);
        case BinaryExpr(:final left, :final right):
          visit(left);
          visit(right);
        case CallExpr(:final name, :final arguments):
          if (_positionalFunctions.contains(name)) positional = true;
          for (final argument in arguments) {
            visit(argument);
          }
        default:
          break;
      }
    }

    visit(expr);
    return _Formula(sheet, address, expr, references, positional);
  }

  void _link(CellKey key, _Formula formula) {
    if (_isVolatile(formula.expr)) _volatile.add(key);
    _graph.add(key, [
      for (final reference in formula.references)
        if (reference.$1 >= 0) reference,
    ]);
  }

  /// [node] with its references moved by [edit], the same instance when
  /// nothing moves, or null when one becomes `#REF!`. Follows exactly what
  /// [adjustReferences] does to the text, so the formula is not parsed again.
  static Expr? _moveExpr(
    Expr node,
    StructureEdit edit,
    bool Function(String? sheet) targets,
  ) {
    switch (node) {
      case ReferenceExpr(:final sheet, :final range):
        if (!targets(sheet)) return node;
        final rows = edit.axis == SheetAxis.rows;
        if (rows ? node.wholeColumns : node.wholeRows) return node;
        final moved = edit.moveRange(range);
        if (moved == null) return null;
        if (moved == range) return node;
        return ReferenceExpr(
          sheet,
          moved,
          wholeColumns: node.wholeColumns,
          wholeRows: node.wholeRows,
        );
      case UnaryExpr(:final operator, :final operand):
        final moved = _moveExpr(operand, edit, targets);
        if (moved == null) return null;
        return identical(moved, operand) ? node : UnaryExpr(operator, moved);
      case BinaryExpr(:final operator, :final left, :final right):
        final a = _moveExpr(left, edit, targets);
        final b = _moveExpr(right, edit, targets);
        if (a == null || b == null) return null;
        return identical(a, left) && identical(b, right)
            ? node
            : BinaryExpr(operator, a, b);
      case CallExpr(:final name, :final arguments):
        List<Expr>? moved;
        for (var i = 0; i < arguments.length; i++) {
          final argument = _moveExpr(arguments[i], edit, targets);
          if (argument == null) return null;
          if (!identical(argument, arguments[i])) {
            (moved ??= [...arguments])[i] = argument;
          }
        }
        return moved == null ? node : CallExpr(name, moved);
      default:
        return node;
    }
  }

  static bool _isVolatile(Expr node) => switch (node) {
    UnaryExpr(:final operand) => _isVolatile(operand),
    BinaryExpr(:final left, :final right) =>
      _isVolatile(left) || _isVolatile(right),
    CallExpr(:final name, :final arguments) =>
      (functionRegistry[name]?.volatile ?? false) || arguments.any(_isVolatile),
    _ => false,
  };

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
