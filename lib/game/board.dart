import 'package:flutter/foundation.dart';

import 'level.dart';

/// Live play state for one level: which cells are owned by which color,
/// the pipe drawn for each color, and the drag in progress.
class Board extends ChangeNotifier {
  final Level level;

  /// Classic rule: every cell must be covered, not just every pair joined.
  final bool requireFill;
  late final List<List<int>> _endpoint; // color at endpoint cells, else -1
  late List<List<int>> _owner; // color at any cell, else -1
  late List<List<Cell>> _paths; // drawn pipe per color, may be empty
  int? _active;
  int _moves = 0;
  bool _won = false;
  int _hintsUsed = 0;

  Board(this.level, {this.requireFill = true}) {
    _endpoint = level.endpointGrid();
    _reset();
  }

  int get size => level.size;
  int get moves => _moves;
  bool get won => _won;
  int? get active => _active;
  int get hintsUsed => _hintsUsed;
  int get colorCount => level.colorCount;

  int ownerAt(Cell c) => _owner[c.r][c.c];
  int endpointAt(Cell c) => _endpoint[c.r][c.c];
  List<Cell> pathOf(int color) => _paths[color];

  bool isComplete(int color) {
    final p = _paths[color];
    if (p.length < 2) return false;
    return _endpoint[p.first.r][p.first.c] == color &&
        _endpoint[p.last.r][p.last.c] == color &&
        p.first != p.last;
  }

  int get completedCount =>
      [for (var i = 0; i < colorCount; i++) if (isComplete(i)) i].length;

  int get filledCount {
    var n = 0;
    for (final row in _owner) {
      for (final v in row) {
        if (v != -1) n++;
      }
    }
    return n;
  }

  /// Share of non-dot cells covered by pipe, so a fresh board reads 0%.
  double get fillFraction {
    final dots = colorCount * 2;
    final total = size * size - dots;
    if (total <= 0) return 1;
    return ((filledCount - dots) / total).clamp(0, 1);
  }

  bool inBounds(Cell c) => c.r >= 0 && c.r < size && c.c >= 0 && c.c < size;

  void _reset() {
    _owner = List.generate(size, (_) => List.filled(size, -1));
    _paths = List.generate(level.colorCount, (_) => <Cell>[]);
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        _owner[r][c] = _endpoint[r][c];
      }
    }
    _active = null;
    _won = false;
  }

  void restart() {
    _reset();
    _moves = 0;
    _hintsUsed = 0;
    notifyListeners();
  }

  // ---- Drag handling -----------------------------------------------------

  /// Finger down on [cell]. Returns true if a drag started.
  bool beginDrag(Cell cell) {
    if (_won || !inBounds(cell)) return false;
    final ep = _endpoint[cell.r][cell.c];
    if (ep != -1) {
      // Start fresh from this dot.
      _clearPath(ep);
      _paths[ep].add(cell);
      _owner[cell.r][cell.c] = ep;
      _active = ep;
      _moves++;
      notifyListeners();
      return true;
    }
    final own = _owner[cell.r][cell.c];
    if (own != -1) {
      // Pick the pipe up where the finger landed and continue from there.
      _truncate(own, cell);
      _active = own;
      _moves++;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Finger moved over [cell]. Returns true if the board changed, and sets
  /// [justCompleted] when this move closed a pipe.
  bool dragTo(Cell cell, {void Function(int color)? onComplete}) {
    final color = _active;
    if (color == null || _won || !inBounds(cell)) return false;
    final path = _paths[color];
    if (path.isEmpty) return false;
    final head = path.last;
    if (cell == head) return false;

    // Backtracking onto our own pipe trims it.
    final idx = path.indexOf(cell);
    if (idx != -1) {
      _truncate(color, cell);
      notifyListeners();
      return true;
    }

    // A completed pipe cannot grow past its dot.
    if (isComplete(color)) return false;

    // Fast drags may skip cells; walk straight lines, ignore diagonals.
    final steps = _lineBetween(head, cell);
    if (steps == null) return false;

    var changed = false;
    for (final next in steps) {
      final ep = _endpoint[next.r][next.c];
      if (ep != -1 && ep != color) break; // another color's dot blocks
      if (ep == color && next == path.first) break; // can't re-enter start
      // Other pipes are solid: you can't cut through them by accident.
      final other = _owner[next.r][next.c];
      if (other != -1 && other != color) break;
      _owner[next.r][next.c] = color;
      path.add(next);
      changed = true;
      if (ep == color) {
        onComplete?.call(color);
        _checkWin();
        break;
      }
    }
    if (changed) notifyListeners();
    return changed;
  }

  void endDrag() {
    if (_active == null) return;
    _active = null;
    notifyListeners();
  }

  /// Draws the solution for one unfinished color.
  bool hint() {
    if (_won) return false;
    final candidates = [
      for (var i = 0; i < colorCount; i++)
        if (!isComplete(i)) i,
    ];
    if (candidates.isEmpty) return false;
    // Prefer colors the player hasn't touched yet.
    candidates.sort((a, b) => _paths[a].length.compareTo(_paths[b].length));
    final color = candidates.first;
    _clearPath(color);
    for (final c in level.solution[color]) {
      final other = _owner[c.r][c.c];
      if (other != -1 && other != color) _truncate(other, c, exclusive: true);
      _owner[c.r][c.c] = color;
    }
    _paths[color] = List.of(level.solution[color]);
    _hintsUsed++;
    _moves++;
    _checkWin();
    notifyListeners();
    return true;
  }

  // ---- Internals ---------------------------------------------------------

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

  void _clearPath(int color) {
    for (final c in _paths[color]) {
      if (_endpoint[c.r][c.c] == color) continue;
      _owner[c.r][c.c] = -1;
    }
    _paths[color] = [];
  }

  /// Keeps the pipe up to and including [cell] (or excluding it when
  /// [exclusive]). Cells after it are released, endpoints keep their color.
  void _truncate(int color, Cell cell, {bool exclusive = false}) {
    final path = _paths[color];
    final idx = path.indexOf(cell);
    if (idx == -1) return;
    final keep = exclusive ? idx : idx + 1;
    for (var i = keep; i < path.length; i++) {
      final c = path[i];
      if (_endpoint[c.r][c.c] == color) continue;
      _owner[c.r][c.c] = -1;
    }
    path.removeRange(keep, path.length);
  }

  void _checkWin() {
    if (completedCount != colorCount) return;
    if (requireFill && filledCount != size * size) return;
    _won = true;
    _active = null;
  }
}
