import 'level.dart';

/// Counts full-fill solutions of a flow puzzle, up to [limit], within a node
/// budget. Used by the generator to keep only puzzles with one solution,
/// which is what makes a level feel fair: connect the pairs the sensible way
/// and the board fills itself.
class FlowSolver {
  final int n;
  final int colors;
  final List<int> owner; // flat grid, -1 free
  final List<int> start; // per color
  final List<int> target; // per color
  final List<int> head;
  final List<bool> done;
  int free;
  int nodes = 0;
  final int budget;
  bool aborted = false;

  FlowSolver(Level level, {this.budget = 150000})
    : n = level.size,
      colors = level.colorCount,
      owner = List.filled(level.size * level.size, -1),
      start = [],
      target = [],
      head = [],
      done = List.filled(level.colorCount, false),
      free = level.size * level.size - level.colorCount * 2 {
    for (var k = 0; k < colors; k++) {
      final p = level.solution[k];
      final a = p.first.r * n + p.first.c;
      final b = p.last.r * n + p.last.c;
      start.add(a);
      target.add(b);
      head.add(a);
      owner[a] = k;
      owner[b] = k;
    }
  }

  /// Returns the number of solutions found (capped at [limit]), or -1 when
  /// the node budget ran out before the search finished.
  int count({int limit = 2}) {
    _found = 0;
    _limit = limit;
    _dfs();
    return aborted ? -1 : _found;
  }

  int _found = 0;
  int _limit = 2;


  int _neighbours(int cell, List<int> out) {
    var m = 0;
    final r = cell ~/ n, c = cell % n;
    if (r > 0) out[m++] = cell - n;
    if (r < n - 1) out[m++] = cell + n;
    if (c > 0) out[m++] = cell - 1;
    if (c < n - 1) out[m++] = cell + 1;
    return m;
  }

  void _dfs() {
    if (aborted || _found >= _limit) return;
    if (++nodes > budget) {
      aborted = true;
      return;
    }
    // Pick the unfinished color with the fewest legal moves.
    var bestK = -1;
    var bestMoves = const <int>[];
    final nb = List.filled(4, 0);
    for (var k = 0; k < colors; k++) {
      if (done[k]) continue;
      final m = _neighbours(head[k], nb);
      final moves = <int>[];
      for (var i = 0; i < m; i++) {
        final x = nb[i];
        if (owner[x] == -1 || x == target[k]) moves.add(x);
      }
      if (moves.isEmpty) return;
      if (bestK == -1 || moves.length < bestMoves.length) {
        bestK = k;
        bestMoves = moves;
        if (moves.length == 1) break;
      }
    }
    if (bestK == -1) {
      if (free == 0) _found++;
      return;
    }
    final k = bestK;
    final prevHead = head[k];
    for (final x in bestMoves) {
      final closing = x == target[k];
      if (closing) {
        done[k] = true;
      } else {
        owner[x] = k;
        free--;
      }
      head[k] = x;
      if (_viable(x, prevHead)) _dfs();
      head[k] = prevHead;
      if (closing) {
        done[k] = false;
      } else {
        owner[x] = -1;
        free++;
      }
      if (aborted || _found >= _limit) return;
    }
  }

  /// Cheap pruning: no stranded free cells around the move, and every pocket
  /// of free cells must still be reachable by some unfinished pipe.
  bool _viable(int moved, int prevHead) {
    final nb = List.filled(4, 0);
    final m = _neighbours(moved, nb);
    for (var i = 0; i < m; i++) {
      if (!_cellOk(nb[i])) return false;
    }
    final m2 = _neighbours(prevHead, nb);
    for (var i = 0; i < m2; i++) {
      if (!_cellOk(nb[i])) return false;
    }
    return _pocketsOk();
  }

  /// A free cell needs at least two usable neighbours (free cells, live heads
  /// or live targets); otherwise nothing can pass through it.
  bool _cellOk(int cell) {
    if (owner[cell] != -1) return true;
    final nb = List.filled(4, 0);
    final m = _neighbours(cell, nb);
    var usable = 0;
    for (var i = 0; i < m; i++) {
      final x = nb[i];
      if (owner[x] == -1) {
        usable++;
      } else {
        final k = owner[x];
        if (!done[k] && (head[k] == x || target[k] == x)) usable++;
      }
    }
    return usable >= 2;
  }

  /// Labels free-cell pockets, then checks that every pocket borders a live
  /// head and a live target, and that every unfinished pipe's head can still
  /// reach its own target through one pocket (or directly).
  bool _pocketsOk() {
    if (free == 0) {
      for (var k = 0; k < colors; k++) {
        if (!done[k] && !_adjacent(head[k], target[k])) return false;
      }
      return true;
    }
    final label = _label..fillRange(0, n * n, -1);
    final nb = List.filled(4, 0);
    final stack = <int>[];
    var pockets = 0;
    for (var s = 0; s < n * n; s++) {
      if (owner[s] != -1 || label[s] != -1) continue;
      final id = pockets++;
      stack.add(s);
      label[s] = id;
      while (stack.isNotEmpty) {
        final cell = stack.removeLast();
        final m = _neighbours(cell, nb);
        for (var i = 0; i < m; i++) {
          final x = nb[i];
          if (owner[x] == -1 && label[x] == -1) {
            label[x] = id;
            stack.add(x);
          }
        }
      }
    }
    // Per pocket: does it touch a live head / a live target?
    final headTouch = List.filled(pockets, false);
    final targetTouch = List.filled(pockets, false);
    for (var k = 0; k < colors; k++) {
      if (done[k]) continue;
      var hm = 0, tm = 0;
      final hp = <int>[];
      final tp = <int>[];
      final m = _neighbours(head[k], nb);
      for (var i = 0; i < m; i++) {
        final l = label[nb[i]];
        if (l != -1) {
          headTouch[l] = true;
          hp.add(l);
          hm++;
        }
      }
      final m2 = _neighbours(target[k], nb);
      for (var i = 0; i < m2; i++) {
        final l = label[nb[i]];
        if (l != -1) {
          targetTouch[l] = true;
          tp.add(l);
          tm++;
        }
      }
      if (_adjacent(head[k], target[k])) continue;
      if (hm == 0 || tm == 0) return false;
      var shared = false;
      for (final a in hp) {
        if (tp.contains(a)) {
          shared = true;
          break;
        }
      }
      if (!shared) return false;
    }
    for (var p = 0; p < pockets; p++) {
      if (!headTouch[p] || !targetTouch[p]) return false;
    }
    return true;
  }

  late final List<int> _label = List.filled(n * n, -1);

  bool _adjacent(int a, int b) {
    final ar = a ~/ n, ac = a % n, br = b ~/ n, bc = b % n;
    return (ar - br).abs() + (ac - bc).abs() == 1;
  }
}
