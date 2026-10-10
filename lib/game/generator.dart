import 'dart:math';

import 'level.dart';

/// Generates random, always-solvable flow puzzles by carving the grid into
/// simple paths. Every cell belongs to exactly one path, so the solution
/// fills the board, which is what makes the puzzle a puzzle.
class LevelGenerator {
  static const int maxColors = 14;

  static Level generate(Difficulty difficulty, {int? seed}) {
    final s = seed ?? Random().nextInt(1 << 31);
    final rng = Random(s);
    final size = difficulty.pickSize(rng);
    final paths = _carve(size, difficulty, rng);
    return Level(
      size: size,
      difficulty: difficulty,
      seed: s,
      solution: paths,
    );
  }

  /// Replays a known level from its seed.
  static Level fromSeed(Difficulty difficulty, int seed) =>
      generate(difficulty, seed: seed);

  static (int, int) _pathCountRange(int size) => switch (size) {
    5 => (4, 5),
    6 => (5, 6),
    7 => (6, 7),
    8 => (7, 8),
    9 => (8, 9),
    10 => (9, 11),
    11 => (10, 12),
    _ => (11, 14),
  };

  static List<List<Cell>> _carve(int size, Difficulty difficulty, Random rng) {
    final (minPaths, maxPaths) = _pathCountRange(size);
    final cells = size * size;
    final target = cells / ((minPaths + maxPaths) / 2);
    // Harder puzzles get longer, more winding pipes.
    final minLen = switch (difficulty) {
      Difficulty.easy => 3,
      Difficulty.medium => 4,
      Difficulty.hard => 5,
      Difficulty.expert => 5,
    };

    for (var attempt = 0; attempt < 400; attempt++) {
      final result = _attempt(size, rng, target, minLen);
      if (result == null) continue;
      if (result.length < minPaths || result.length > maxPaths) continue;
      if (result.length > maxColors) continue;
      // Avoid boring puzzles where many pairs sit right next to each other.
      final straight = result.where(_isStraight).length;
      if (straight > result.length ~/ 3) continue;
      result.shuffle(rng);
      return result;
    }
    // Extremely unlikely; fall back to a serpentine cut so we never hang.
    return _serpentine(size, minPaths);
  }

  static bool _isStraight(List<Cell> p) {
    if (p.length > 3) return false;
    final rows = p.map((c) => c.r).toSet();
    final cols = p.map((c) => c.c).toSet();
    return rows.length == 1 || cols.length == 1;
  }

  static List<List<Cell>>? _attempt(
    int size,
    Random rng,
    double targetLen,
    int minLen,
  ) {
    final owner = List.generate(size, (_) => List.filled(size, -1));
    final paths = <List<Cell>>[];

    final order = [
      for (var r = 0; r < size; r++)
        for (var c = 0; c < size; c++) Cell(r, c),
    ]..shuffle(rng);

    bool free(int r, int c) =>
        r >= 0 && r < size && c >= 0 && c < size && owner[r][c] == -1;

    List<Cell> freeNeighbours(Cell x) => [
      if (free(x.r - 1, x.c)) Cell(x.r - 1, x.c),
      if (free(x.r + 1, x.c)) Cell(x.r + 1, x.c),
      if (free(x.r, x.c - 1)) Cell(x.r, x.c - 1),
      if (free(x.r, x.c + 1)) Cell(x.r, x.c + 1),
    ];

    for (final start in order) {
      if (owner[start.r][start.c] != -1) continue;
      final id = paths.length;
      final path = <Cell>[start];
      owner[start.r][start.c] = id;
      var cur = start;
      final cap = (targetLen * 1.7).round();
      while (path.length < cap) {
        final options = freeNeighbours(cur);
        if (options.isEmpty) break;
        // Stop early once long enough, so lengths vary.
        if (path.length >= targetLen && rng.nextDouble() < 0.45) break;
        options.shuffle(rng);
        // Warnsdorff-style bias: prefer cells with few free neighbours so we
        // don't strand single cells behind us.
        Cell next;
        if (rng.nextDouble() < 0.6) {
          next = options.reduce(
            (a, b) =>
                freeNeighbours(a).length <= freeNeighbours(b).length ? a : b,
          );
        } else {
          next = options.first;
        }
        owner[next.r][next.c] = id;
        path.add(next);
        cur = next;
      }
      paths.add(path);
    }

    // Absorb short paths into neighbouring paths' ends.
    var changed = true;
    while (changed) {
      changed = false;
      for (var i = 0; i < paths.length; i++) {
        final p = paths[i];
        if (p.length >= minLen) continue;
        if (_absorb(paths, i, owner)) {
          changed = true;
          break;
        }
      }
    }
    if (paths.any((p) => p.length < minLen)) return null;
    // Renumber owners is unnecessary; the caller only needs the paths.
    return paths;
  }

  /// Tries to append the short path [i] (in either orientation) onto the end
  /// of another path whose endpoint is adjacent. Returns true on success.
  static bool _absorb(List<List<Cell>> paths, int i, List<List<int>> owner) {
    final short = paths[i];
    for (var j = 0; j < paths.length; j++) {
      if (j == i) continue;
      final other = paths[j];
      for (final orientation in [short, short.reversed.toList()]) {
        final head = orientation.first;
        if (other.last.isAdjacent(head)) {
          other.addAll(orientation);
          _retag(orientation, j, owner);
          paths.removeAt(i);
          return true;
        }
        if (other.first.isAdjacent(head)) {
          other.insertAll(0, orientation.reversed);
          _retag(orientation, j, owner);
          paths.removeAt(i);
          return true;
        }
      }
    }
    return false;
  }

  static void _retag(List<Cell> cells, int id, List<List<int>> owner) {
    for (final c in cells) {
      owner[c.r][c.c] = id;
    }
  }

  static List<List<Cell>> _serpentine(int size, int count) {
    final all = <Cell>[];
    for (var r = 0; r < size; r++) {
      final row = [for (var c = 0; c < size; c++) Cell(r, c)];
      all.addAll(r.isEven ? row : row.reversed);
    }
    final per = (all.length / count).ceil();
    return [
      for (var i = 0; i < all.length; i += per)
        all.sublist(i, min(i + per, all.length)),
    ].where((p) => p.length >= 2).toList();
  }
}
