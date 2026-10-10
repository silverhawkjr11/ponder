import 'dart:math';

import 'package:flutter/foundation.dart';

import 'level.dart';
import 'zip_level.dart';
import 'zip_solver.dart';

/// Builds Zip puzzles: a random Hamiltonian path, numbered waypoints along
/// it, a few walls for character, then more walls or numbers until the
/// solver confirms the solution is unique.
class ZipGenerator {
  static ZipLevel generate(Difficulty difficulty, {int? seed}) {
    final s = seed ?? Random().nextInt(1 << 31);
    final rng = Random(s);
    final size = difficulty.zipSize;
    final (minNum, maxNum, startWalls, maxWalls) = switch (difficulty) {
      Difficulty.easy => (4, 6, 1, 5),
      Difficulty.medium => (6, 8, 3, 9),
      Difficulty.hard => (8, 10, 5, 14),
      Difficulty.expert => (9, 12, 7, 20),
    };

    ZipLevel? fallback;
    for (var candidate = 0; candidate < 60; candidate++) {
      final path = _hamiltonianPath(size, rng);
      final waypointIdx = _pickWaypoints(
        path.length,
        minNum + rng.nextInt(maxNum - minNum + 1),
        rng,
      );
      final walls = <int>{};
      _addRandomWalls(size, path, walls, startWalls, rng);

      // Tighten until unique.
      for (var step = 0; step < 24; step++) {
        final level = ZipLevel(
          size: size,
          difficulty: difficulty,
          seed: s,
          solution: path,
          waypoints: [for (final i in waypointIdx) path[i]],
          walls: Set.of(walls),
        );
        final solver = ZipSolver(level, budget: 150000);
        final n = solver.count(limit: 2);
        if (n == 1) return level;
        if (n == -1) {
          fallback ??= level;
          break;
        }
        // Use the rival solution to pick a wall or number that kills it.
        final rival = solver.found.firstWhere(
          (f) => !_samePath(f, path, size),
          orElse: () => solver.found.last,
        );
        var i = 0;
        while (i < path.length && rival[i] == path[i].r * size + path[i].c) {
          i++;
        }
        if (i == 0 || i >= path.length) break;
        final from = path[i - 1];
        final to = Cell(rival[i] ~/ size, rival[i] % size);
        final key = ZipLevel.wallKey(size, from, to);
        if (walls.length < maxWalls && !walls.contains(key)) {
          walls.add(key);
        } else if (waypointIdx.length < maxNum &&
            !waypointIdx.contains(i) &&
            !waypointIdx.contains(i - 1) &&
            !waypointIdx.contains(i + 1)) {
          waypointIdx
            ..add(i)
            ..sort();
        } else {
          break; // give up on this path, try a fresh one
        }
      }
    }
    if (fallback != null) return fallback;
    final path = _hamiltonianPath(size, rng);
    return ZipLevel(
      size: size,
      difficulty: difficulty,
      seed: s,
      solution: path,
      waypoints: [path.first, path.last],
      walls: const {},
    );
  }

  static Future<ZipLevel> generateAsync(Difficulty difficulty, {int? seed}) =>
      compute(_entry, (difficulty.index, seed));

  static bool _samePath(List<int> flat, List<Cell> path, int size) {
    for (var i = 0; i < path.length; i++) {
      if (flat[i] != path[i].r * size + path[i].c) return false;
    }
    return true;
  }

  /// Random Hamiltonian path on the grid via backbite moves from a serpentine.
  static List<Cell> _hamiltonianPath(int size, Random rng) {
    final path = <Cell>[];
    for (var r = 0; r < size; r++) {
      final row = [for (var c = 0; c < size; c++) Cell(r, c)];
      path.addAll(r.isEven ? row : row.reversed);
    }
    final pos = <Cell, int>{for (var i = 0; i < path.length; i++) path[i]: i};
    final iterations = 40 * size * size;
    for (var it = 0; it < iterations; it++) {
      if (rng.nextBool()) {
        _reverse(path, pos, 0, path.length - 1);
      }
      final head = path.last;
      final options = <Cell>[];
      for (final d in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final c = Cell(head.r + d.$1, head.c + d.$2);
        if (c.r < 0 || c.r >= size || c.c < 0 || c.c >= size) continue;
        final p = pos[c]!;
        if (p < path.length - 2) options.add(c);
      }
      if (options.isEmpty) continue;
      final pick = options[rng.nextInt(options.length)];
      _reverse(path, pos, pos[pick]! + 1, path.length - 1);
    }
    return path;
  }

  static void _reverse(List<Cell> path, Map<Cell, int> pos, int a, int b) {
    while (a < b) {
      final t = path[a];
      path[a] = path[b];
      path[b] = t;
      pos[path[a]] = a;
      pos[path[b]] = b;
      a++;
      b--;
    }
  }

  /// Picks path indices for the numbers: first, last, and spread interiors.
  static List<int> _pickWaypoints(int length, int count, Random rng) {
    final idx = <int>{0, length - 1};
    var guard = 0;
    while (idx.length < count && guard++ < 500) {
      final i = 1 + rng.nextInt(length - 2);
      if (idx.any((j) => (j - i).abs() < 2)) continue;
      idx.add(i);
    }
    return idx.toList()..sort();
  }

  static void _addRandomWalls(
    int size,
    List<Cell> path,
    Set<int> walls,
    int count,
    Random rng,
  ) {
    final pos = <Cell, int>{for (var i = 0; i < path.length; i++) path[i]: i};
    final candidates = <int>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final a = Cell(r, c);
        for (final b in [Cell(r, c + 1), Cell(r + 1, c)]) {
          if (b.r >= size || b.c >= size) continue;
          if ((pos[a]! - pos[b]!).abs() == 1) continue; // path uses this edge
          candidates.add(ZipLevel.wallKey(size, a, b));
        }
      }
    }
    candidates.shuffle(rng);
    walls.addAll(candidates.take(count));
  }
}

ZipLevel _entry((int, int?) args) =>
    ZipGenerator.generate(Difficulty.values[args.$1], seed: args.$2);
