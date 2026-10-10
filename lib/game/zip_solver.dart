import 'level.dart';
import 'zip_level.dart';

/// Counts solutions of a Zip puzzle (up to a limit, within a node budget) and
/// keeps the ones it finds so the generator can break ambiguity precisely.
class ZipSolver {
  final int n;
  final Set<int> walls;
  final List<int> number; // flat, 0 = none
  final int last; // N
  final int startCell;
  final List<bool> visited;
  final List<int> path = [];
  final List<List<int>> found = [];
  final int budget;
  int nodes = 0;
  bool aborted = false;
  int _limit = 2;

  ZipSolver(ZipLevel level, {this.budget = 200000})
    : n = level.size,
      walls = level.walls,
      number = List.filled(level.size * level.size, 0),
      last = level.numberCount,
      startCell = level.waypoints.first.r * level.size + level.waypoints.first.c,
      visited = List.filled(level.size * level.size, false) {
    for (var i = 0; i < level.waypoints.length; i++) {
      final w = level.waypoints[i];
      number[w.r * n + w.c] = i + 1;
    }
  }

  int count({int limit = 2}) {
    _limit = limit;
    found.clear();
    nodes = 0;
    aborted = false;
    visited[startCell] = true;
    path.add(startCell);
    _dfs(startCell, 2, n * n - 1);
    path.clear();
    visited.fillRange(0, n * n, false);
    return aborted ? -1 : found.length;
  }

  bool _open(int a, int b) {
    final ar = a ~/ n, ac = a % n, br = b ~/ n, bc = b % n;
    return !walls.contains(ZipLevel.wallKey(n, Cell(ar, ac), Cell(br, bc)));
  }

  int _neighbours(int cell, List<int> out) {
    var m = 0;
    final r = cell ~/ n, c = cell % n;
    if (r > 0 && _open(cell, cell - n)) out[m++] = cell - n;
    if (r < n - 1 && _open(cell, cell + n)) out[m++] = cell + n;
    if (c > 0 && _open(cell, cell - 1)) out[m++] = cell - 1;
    if (c < n - 1 && _open(cell, cell + 1)) out[m++] = cell + 1;
    return m;
  }

  void _dfs(int cell, int next, int remaining) {
    if (aborted || found.length >= _limit) return;
    if (++nodes > budget) {
      aborted = true;
      return;
    }
    if (remaining == 0) {
      if (next > last) found.add(List.of(path));
      return;
    }
    final nb = List.filled(4, 0);
    final m = _neighbours(cell, nb);
    for (var i = 0; i < m; i++) {
      final x = nb[i];
      if (visited[x]) continue;
      final num = number[x];
      if (num != 0 && num != next) continue;
      if (num == last && remaining > 1) continue;
      visited[x] = true;
      path.add(x);
      if (_viable(x, remaining - 1)) {
        _dfs(x, num == next ? next + 1 : next, remaining - 1);
      }
      path.removeLast();
      visited[x] = false;
      if (aborted || found.length >= _limit) return;
    }
  }

  late final List<int> _stack = [];
  late final List<bool> _seen = List.filled(n * n, false);

  /// All free cells must be one pocket reachable from the head, and at most
  /// one free cell may be a dead end, which then has to be the final number.
  bool _viable(int head, int remaining) {
    if (remaining == 0) return true;
    final nb = List.filled(4, 0);
    _seen.fillRange(0, n * n, false);
    var reached = 0;
    var deadEnds = 0;
    final m0 = _neighbours(head, nb);
    for (var i = 0; i < m0; i++) {
      final x = nb[i];
      if (!visited[x] && !_seen[x]) {
        _seen[x] = true;
        _stack.add(x);
      }
    }
    if (_stack.isEmpty) return false;
    while (_stack.isNotEmpty) {
      final cell = _stack.removeLast();
      reached++;
      final m = _neighbours(cell, nb);
      var degree = 0;
      for (var i = 0; i < m; i++) {
        final x = nb[i];
        if (x == head) {
          degree++;
        } else if (!visited[x]) {
          degree++;
          if (!_seen[x]) {
            _seen[x] = true;
            _stack.add(x);
          }
        }
      }
      if (degree <= 1) {
        if (number[cell] != last) {
          _stack.clear();
          return false;
        }
        deadEnds++;
      }
    }
    if (reached != remaining) return false;
    return deadEnds <= 1;
  }
}
