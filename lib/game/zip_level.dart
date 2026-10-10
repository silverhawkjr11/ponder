import 'level.dart';

/// A Zip puzzle: draw one path from 1 to N through every cell, visiting the
/// numbers in order and never crossing a wall.
class ZipLevel {
  final int size;
  final Difficulty difficulty;
  final int seed;

  /// The intended path, covering every cell, starting at number 1.
  final List<Cell> solution;

  /// Numbered cells in order: waypoints[0] is "1", the last is "N".
  final List<Cell> waypoints;

  /// Wall keys, see [wallKey].
  final Set<int> walls;

  const ZipLevel({
    required this.size,
    required this.difficulty,
    required this.seed,
    required this.solution,
    required this.waypoints,
    required this.walls,
  });

  int get numberCount => waypoints.length;

  /// Encodes the wall between two adjacent cells.
  static int wallKey(int size, Cell a, Cell b) {
    if (a.r == b.r) {
      final c = a.c < b.c ? a.c : b.c;
      return (a.r * size + c) * 2;
    }
    final r = a.r < b.r ? a.r : b.r;
    return (r * size + a.c) * 2 + 1;
  }

  bool hasWall(Cell a, Cell b) => walls.contains(wallKey(size, a, b));

  /// 1-based number at a cell, or 0.
  List<List<int>> numberGrid() {
    final g = List.generate(size, (_) => List.filled(size, 0));
    for (var i = 0; i < waypoints.length; i++) {
      g[waypoints[i].r][waypoints[i].c] = i + 1;
    }
    return g;
  }
}
