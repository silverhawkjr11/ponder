import 'dart:math';

import 'package:flutter/foundation.dart';

import 'level.dart';

/// A sudoku with a unique solution.
class SudokuLevel {
  final Difficulty difficulty;
  final int seed;
  final List<int> givens; // 81 cells, 0 = empty
  final List<int> solution;
  const SudokuLevel({
    required this.difficulty,
    required this.seed,
    required this.givens,
    required this.solution,
  });

  int get clueCount => givens.where((v) => v != 0).length;
}

class SudokuGenerator {
  static SudokuLevel generate(Difficulty difficulty, {int? seed}) {
    final s = seed ?? Random().nextInt(1 << 31);
    final rng = Random(s);
    final solution = List.filled(81, 0);
    _fill(solution, 0, rng);
    final grid = List.of(solution);
    final target = difficulty.sudokuClues;
    // Remove symmetric pairs while the puzzle stays unique.
    final order = List.generate(41, (i) => i)..shuffle(rng);
    var clues = 81;
    for (final i in order) {
      if (clues <= target) break;
      final j = 80 - i;
      final a = grid[i], b = grid[j];
      grid[i] = 0;
      grid[j] = 0;
      if (_countSolutions(List.of(grid), 2) == 1) {
        clues -= i == j ? 1 : 2;
      } else {
        grid[i] = a;
        grid[j] = b;
      }
    }
    // Second pass, single cells, to reach harder targets.
    if (clues > target) {
      final singles = List.generate(81, (i) => i)..shuffle(rng);
      for (final i in singles) {
        if (clues <= target) break;
        if (grid[i] == 0) continue;
        final a = grid[i];
        grid[i] = 0;
        if (_countSolutions(List.of(grid), 2) == 1) {
          clues--;
        } else {
          grid[i] = a;
        }
      }
    }
    return SudokuLevel(
      difficulty: difficulty,
      seed: s,
      givens: grid,
      solution: solution,
    );
  }

  static Future<SudokuLevel> generateAsync(Difficulty d, {int? seed}) =>
      compute(_entry, (d.index, seed));

  static bool _ok(List<int> g, int idx, int v) {
    final r = idx ~/ 9, c = idx % 9;
    for (var k = 0; k < 9; k++) {
      if (g[r * 9 + k] == v || g[k * 9 + c] == v) return false;
    }
    final br = (r ~/ 3) * 3, bc = (c ~/ 3) * 3;
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        if (g[(br + i) * 9 + bc + j] == v) return false;
      }
    }
    return true;
  }

  static bool _fill(List<int> g, int idx, Random rng) {
    if (idx == 81) return true;
    final digits = [1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle(rng);
    for (final d in digits) {
      if (_ok(g, idx, d)) {
        g[idx] = d;
        if (_fill(g, idx + 1, rng)) return true;
        g[idx] = 0;
      }
    }
    return false;
  }

  /// Backtracking count with most-constrained-cell ordering.
  static int _countSolutions(List<int> g, int limit) {
    var best = -1, bestCount = 10;
    List<int>? bestCands;
    for (var i = 0; i < 81; i++) {
      if (g[i] != 0) continue;
      final cands = [for (var v = 1; v <= 9; v++) if (_ok(g, i, v)) v];
      if (cands.isEmpty) return 0;
      if (cands.length < bestCount) {
        best = i;
        bestCount = cands.length;
        bestCands = cands;
        if (bestCount == 1) break;
      }
    }
    if (best == -1) return 1;
    var total = 0;
    for (final v in bestCands!) {
      g[best] = v;
      total += _countSolutions(g, limit - total);
      g[best] = 0;
      if (total >= limit) break;
    }
    return total;
  }
}

SudokuLevel _entry((int, int?) args) =>
    SudokuGenerator.generate(Difficulty.values[args.$1], seed: args.$2);

class _Snapshot {
  final int idx;
  final int value;
  final Set<int> notes;
  _Snapshot(this.idx, this.value, this.notes);
}

/// Play state for a sudoku: values, pencil notes, mistakes and undo.
class SudokuBoard extends ChangeNotifier {
  final SudokuLevel level;
  late List<int> values;
  late List<Set<int>> notes;
  final List<_Snapshot> _undo = [];
  int? selected;
  bool pencil = false;
  int mistakes = 0;
  int hintsUsed = 0;
  bool _won = false;

  SudokuBoard(this.level) {
    _reset();
  }

  bool get won => _won;
  bool isGiven(int i) => level.givens[i] != 0;
  bool isWrong(int i) => values[i] != 0 && values[i] != level.solution[i];
  int get filled => values.where((v) => v != 0).length;
  int remainingOf(int d) => 9 - values.where((v) => v == d).length;
  bool get canUndo => _undo.isNotEmpty;

  void _reset() {
    values = List.of(level.givens);
    notes = List.generate(81, (_) => <int>{});
    _undo.clear();
    selected = null;
    pencil = false;
    _won = false;
  }

  void restart() {
    _reset();
    mistakes = 0;
    hintsUsed = 0;
    notifyListeners();
  }

  void select(int i) {
    selected = selected == i ? null : i;
    notifyListeners();
  }

  void togglePencil() {
    pencil = !pencil;
    notifyListeners();
  }

  void _snapshot(int i) =>
      _undo.add(_Snapshot(i, values[i], Set.of(notes[i])));

  void enter(int d) {
    final i = selected;
    if (i == null || _won || isGiven(i)) return;
    _snapshot(i);
    if (pencil) {
      if (values[i] != 0) {
        _undo.removeLast();
        return;
      }
      if (!notes[i].remove(d)) notes[i].add(d);
      notifyListeners();
      return;
    }
    if (values[i] == d) {
      values[i] = 0;
      notifyListeners();
      return;
    }
    values[i] = d;
    notes[i].clear();
    if (d != level.solution[i]) {
      mistakes++;
    } else {
      _clearPeerNotes(i, d);
    }
    _checkWin();
    notifyListeners();
  }

  void erase() {
    final i = selected;
    if (i == null || _won || isGiven(i)) return;
    if (values[i] == 0 && notes[i].isEmpty) return;
    _snapshot(i);
    values[i] = 0;
    notes[i].clear();
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty || _won) return;
    final s = _undo.removeLast();
    values[s.idx] = s.value;
    notes[s.idx] = s.notes;
    selected = s.idx;
    notifyListeners();
  }

  /// Fills the selected cell, or a random empty one, with the right digit.
  bool hint() {
    if (_won) return false;
    var i = selected;
    if (i == null || isGiven(i) || values[i] == level.solution[i]) {
      final empties = [
        for (var k = 0; k < 81; k++)
          if (values[k] != level.solution[k]) k,
      ];
      if (empties.isEmpty) return false;
      i = empties[Random().nextInt(empties.length)];
    }
    _snapshot(i);
    values[i] = level.solution[i];
    notes[i].clear();
    selected = i;
    hintsUsed++;
    _clearPeerNotes(i, values[i]);
    _checkWin();
    notifyListeners();
    return true;
  }

  static bool peers(int a, int b) {
    if (a == b) return false;
    final ar = a ~/ 9, ac = a % 9, br = b ~/ 9, bc = b % 9;
    return ar == br || ac == bc || (ar ~/ 3 == br ~/ 3 && ac ~/ 3 == bc ~/ 3);
  }

  void _clearPeerNotes(int i, int d) {
    for (var k = 0; k < 81; k++) {
      if (peers(i, k)) notes[k].remove(d);
    }
  }

  void _checkWin() {
    for (var k = 0; k < 81; k++) {
      if (values[k] != level.solution[k]) return;
    }
    _won = true;
  }
}
