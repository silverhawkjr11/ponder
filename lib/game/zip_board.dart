import 'package:flutter/foundation.dart';

import 'level.dart';
import 'zip_level.dart';

/// Live play state for a Zip level.
class ZipBoard extends ChangeNotifier {
  final ZipLevel level;
  late final List<List<int>> _number; // 1-based, 0 = none
  late List<List<bool>> _visited;
  late List<Cell> _path;
  bool _active = false;
  bool _won = false;
  int _hintsUsed = 0;
  int _moves = 0;

  ZipBoard(this.level) {
    _number = level.numberGrid();
    _reset();
  }

  int get size => level.size;
  int get total => size * size;
  bool get won => _won;
  bool get active => _active;
  int get hintsUsed => _hintsUsed;
  int get moves => _moves;
  int get numberCount => level.numberCount;
  List<Cell> get path => List.unmodifiable(_path);
  Cell get head => _path.last;
  int numberAt(Cell c) => _number[c.r][c.c];
  bool visited(Cell c) => _visited[c.r][c.c];
  int get filledCount => _path.length;
  double get fillFraction => (_path.length - 1) / (total - 1);

  /// Highest number reached so far (1..N).
  int get reached {
    var best = 0;
    for (final c in _path) {
      final n = _number[c.r][c.c];
      if (n > best) best = n;
    }
    return best;
  }

  int get nextNumber => reached + 1;

  bool inBounds(Cell c) => c.r >= 0 && c.r < size && c.c >= 0 && c.c < size;

  void _reset() {
    _visited = List.generate(size, (_) => List.filled(size, false));
    final start = level.waypoints.first;
    _path = [start];
    _visited[start.r][start.c] = true;
    _won = false;
    _active = false;
  }

  void restart() {
    _reset();
    _hintsUsed = 0;
    _moves = 0;
    notifyListeners();
  }

  bool beginDrag(Cell cell) {
    if (_won || !inBounds(cell)) return false;
    if (_visited[cell.r][cell.c]) {
      _truncateTo(cell);
      _active = true;
      _moves++;
      notifyListeners();
      return true;
    }
    if (_canStep(head, cell)) {
      _step(cell);
      _active = true;
      _moves++;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool dragTo(Cell cell, {VoidCallback? onNumber}) {
    if (!_active || _won || !inBounds(cell)) return false;
    if (cell == head) return false;
    if (_visited[cell.r][cell.c]) {
      _truncateTo(cell);
      notifyListeners();
      return true;
    }
    final steps = _lineBetween(head, cell);
    if (steps == null) return false;
    var changed = false;
    for (final next in steps) {
      if (!_canStep(head, next)) break;
      final wasNumber = _number[next.r][next.c] != 0;
      _step(next);
      changed = true;
      if (wasNumber) onNumber?.call();
      if (_won) break;
    }
    if (changed) notifyListeners();
    return changed;
  }

  void endDrag() {
    if (!_active) return;
    _active = false;
    notifyListeners();
  }

  /// Rewinds to the longest correct prefix, then follows the solution up to
  /// and including the next number.
  bool hint() {
    if (_won) return false;
    final sol = level.solution;
    var ok = 0;
    while (ok < _path.length && ok < sol.length && _path[ok] == sol[ok]) {
      ok++;
    }
    _truncateTo(sol[ok - 1]);
    for (var i = ok; i < sol.length; i++) {
      _step(sol[i]);
      if (_number[sol[i].r][sol[i].c] != 0) break;
    }
    _hintsUsed++;
    _active = false;
    notifyListeners();
    return true;
  }

  // ---- internals -------------------------------------------------------

  bool _canStep(Cell from, Cell to) {
    if (!inBounds(to) || _visited[to.r][to.c]) return false;
    if (!from.isAdjacent(to) || level.hasWall(from, to)) return false;
    final num = _number[to.r][to.c];
    if (num == 0) return true;
    if (num != nextNumber) return false;
    if (num == numberCount && _path.length < total - 1) return false;
    return true;
  }

  void _step(Cell to) {
    _visited[to.r][to.c] = true;
    _path.add(to);
    if (_path.length == total) {
      _won = true;
      _active = false;
    }
  }

  void _truncateTo(Cell cell) {
    final idx = _path.indexOf(cell);
    if (idx == -1) return;
    for (var i = idx + 1; i < _path.length; i++) {
      _visited[_path[i].r][_path[i].c] = false;
    }
    _path.removeRange(idx + 1, _path.length);
  }

  List<Cell>? _lineBetween(Cell a, Cell b) {
    if (a.r == b.r) {
      final step = b.c > a.c ? 1 : -1;
      return [for (var c = a.c + step; c != b.c + step; c += step) Cell(a.r, c)];
    }
    if (a.c == b.c) {
      final step = b.r > a.r ? 1 : -1;
      return [for (var r = a.r + step; r != b.r + step; r += step) Cell(r, a.c)];
    }
    return null;
  }
}
