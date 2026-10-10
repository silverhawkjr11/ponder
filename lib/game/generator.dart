import 'dart:math';

import 'package:flutter/foundation.dart';

import 'level.dart';
import 'solver.dart';

/// Generates random flow puzzles by carving the grid into tight paths, then
/// keeps only candidates whose full-fill solution is unique (checked with
/// [FlowSolver]). Unique puzzles play like the classic ones: connecting the
/// pairs the natural way fills the board on its own.
class LevelGenerator {
  static const int maxColors = 14;


  static Level generate(Difficulty difficulty, {int? seed}) {
    final s = seed ?? Random().nextInt(1 << 31);
    final rng = Random(s);
    final size = difficulty.pickSize(rng);
    final paths = _carveUnique(size, difficulty, rng);
    return Level(
      size: size,
      difficulty: difficulty,
      seed: s,
      solution: paths,
    );
  }

  static Level fromSeed(Difficulty difficulty, int seed) =>
      generate(difficulty, seed: seed);

  /// Generates on a background isolate so big boards never freeze the UI.
  static Future<Level> generateAsync(Difficulty difficulty, {int? seed}) =>
      compute(_generateEntry, (difficulty.index, seed));

  static (int, int) _pathCountRange(int size) => switch (size) {
    5 => (4, 5),
    6 => (5, 6),
    7 => (6, 8),
    8 => (8, 9),
    9 => (9, 11),
    _ => (12, 14),
  };

  static List<List<Cell>> _carveUnique(
    int size,
    Difficulty difficulty,
    Random rng,
  ) {
    // Larger boards get a bigger search budget per candidate; past a point we
    // accept a tight candidate even if uniqueness could not be proven.
    final budget = switch (size) {
      <= 6 => 40000,
      <= 8 => 120000,
      _ => 150000,
    };
    final maxCandidates = size <= 8 ? 400 : 60;
    List<List<Cell>>? fallback;
    for (var i = 0; i < maxCandidates; i++) {
      final paths = _carve(size, difficulty, rng);
      final level = Level(
        size: size,
        difficulty: difficulty,
        seed: 0,
        solution: paths,
      );
      final n = FlowSolver(level, budget: budget).count(limit: 2);
      if (n == 1) return paths;
      if (n == -1) fallback ??= paths; // unknown: keep as a last resort
    }
    return fallback ?? _carve(size, difficulty, rng);
  }

  static List<List<Cell>> _carve(int size, Difficulty difficulty, Random rng) {
    final (minPaths, maxPaths) = _pathCountRange(size);
    final cells = size * size;
    final target = cells / ((minPaths + maxPaths) / 2);
    final minLen = switch (difficulty) {
      Difficulty.easy => 3,
      Difficulty.medium => 3,
      Difficulty.hard => 4,
      Difficulty.expert => 4,
    };

    for (var attempt = 0; attempt < 3000; attempt++) {
      final result = _attempt(size, rng, target, minLen);
      if (result == null) continue;
      if (result.length < minPaths || result.length > maxPaths) continue;
      if (result.length > maxColors) continue;
      if (result.any(_touchesItself)) continue;
      result.shuffle(rng);
      return result;
    }
    return _serpentine(size, minPaths);
  }

  /// True when two non-consecutive cells of the path are adjacent. Such a
  /// path could be shortcut, which makes the puzzle loose and ambiguous.
  static bool _touchesItself(List<Cell> p) {
    for (var i = 0; i < p.length; i++) {
      for (var j = i + 2; j < p.length; j++) {
        if (p[i].isAdjacent(p[j])) return true;
      }
    }
    return false;
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

    // A candidate next cell must only touch the path at the current head,
    // so the path stays tight.
    bool tight(Cell next, Cell head, int id) {
      for (final d in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final r = next.r + d.$1, c = next.c + d.$2;
        if (r < 0 || r >= size || c < 0 || c >= size) continue;
        if (owner[r][c] == id && !(r == head.r && c == head.c)) return false;
      }
      return true;
    }

    for (final start in order) {
      if (owner[start.r][start.c] != -1) continue;
      final id = paths.length;
      final path = <Cell>[start];
      owner[start.r][start.c] = id;
      var cur = start;
      final cap = (targetLen * 1.6).round();
      while (path.length < cap) {
        final options = freeNeighbours(cur).where((x) => tight(x, cur, id)).toList();
        if (options.isEmpty) break;
        if (path.length >= targetLen && rng.nextDouble() < 0.45) break;
        options.shuffle(rng);
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

    var changed = true;
    while (changed) {
      changed = false;
      for (var i = 0; i < paths.length; i++) {
        if (paths[i].length >= minLen) continue;
        if (_absorb(paths, i)) {
          changed = true;
          break;
        }
      }
    }
    if (paths.any((p) => p.length < minLen)) return null;
    return paths;
  }

  static bool _absorb(List<List<Cell>> paths, int i) {
    final short = paths[i];
    for (var j = 0; j < paths.length; j++) {
      if (j == i) continue;
      final other = paths[j];
      for (final orientation in [short, short.reversed.toList()]) {
        final head = orientation.first;
        if (other.last.isAdjacent(head)) {
          final merged = [...other, ...orientation];
          if (_touchesItself(merged)) continue;
          paths[j] = merged;
          paths.removeAt(i);
          return true;
        }
        if (other.first.isAdjacent(head)) {
          final merged = [...orientation.reversed, ...other];
          if (_touchesItself(merged)) continue;
          paths[j] = merged;
          paths.removeAt(i);
          return true;
        }
      }
    }
    return false;
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

Level _generateEntry((int, int?) args) =>
    LevelGenerator.generate(Difficulty.values[args.$1], seed: args.$2);
