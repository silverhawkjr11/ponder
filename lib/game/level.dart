import 'dart:math';

/// A cell on the board. Immutable value type.
class Cell {
  final int r;
  final int c;
  const Cell(this.r, this.c);

  bool isAdjacent(Cell o) => (r - o.r).abs() + (c - o.c).abs() == 1;

  @override
  bool operator ==(Object other) => other is Cell && other.r == r && other.c == c;

  @override
  int get hashCode => r * 97 + c;

  @override
  String toString() => '($r,$c)';
}

enum GameMode {
  flow('Flow', 'Join every pair of dots'),
  zip('Zip', 'One path, 1 to N, through every cell');

  final String label;
  final String tagline;
  const GameMode(this.label, this.tagline);
}

enum Difficulty {
  easy('Easy', [5, 6], 5),
  medium('Medium', [7, 8], 6),
  hard('Hard', [9], 7),
  expert('Expert', [10], 8);

  final String label;
  final List<int> sizes; // flow boards
  final int zipSize;
  const Difficulty(this.label, this.sizes, this.zipSize);

  int pickSize(Random rng) => sizes[rng.nextInt(sizes.length)];

  List<int> sizesFor(GameMode mode) =>
      mode == GameMode.flow ? sizes : [zipSize];
}

/// A generated puzzle: a square grid fully covered by a set of simple paths.
/// Each path's first and last cell are the dots the player must connect.
class Level {
  final int size;
  final Difficulty difficulty;
  final int seed;
  final List<List<Cell>> solution;

  const Level({
    required this.size,
    required this.difficulty,
    required this.seed,
    required this.solution,
  });

  int get colorCount => solution.length;

  List<(Cell, Cell)> get endpoints =>
      [for (final p in solution) (p.first, p.last)];

  /// Color index owning each endpoint cell, or -1.
  List<List<int>> endpointGrid() {
    final g = List.generate(size, (_) => List.filled(size, -1));
    for (var i = 0; i < solution.length; i++) {
      final p = solution[i];
      g[p.first.r][p.first.c] = i;
      g[p.last.r][p.last.c] = i;
    }
    return g;
  }
}
