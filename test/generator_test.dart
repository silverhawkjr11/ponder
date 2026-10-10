import 'dart:math';

import 'package:connect_the_dots/game/generator.dart';
import 'package:connect_the_dots/game/level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final d in Difficulty.values) {
    test('${d.label} levels cover the grid with simple paths', () {
      final counts = <int>[];
      for (var seed = 0; seed < 200; seed++) {
        final l = LevelGenerator.generate(d, seed: seed);
        final seen = <Cell>{};
        for (final p in l.solution) {
          expect(p.length, greaterThanOrEqualTo(3), reason: 'seed $seed');
          for (var k = 0; k < p.length; k++) {
            expect(seen.add(p[k]), isTrue, reason: 'dup ${p[k]} seed $seed');
            if (k > 0) expect(p[k].isAdjacent(p[k - 1]), isTrue);
          }
        }
        expect(seen.length, l.size * l.size, reason: 'coverage seed $seed');
        expect(l.colorCount, lessThanOrEqualTo(LevelGenerator.maxColors));
        counts.add(l.colorCount);
      }
      expect(counts.reduce(min), greaterThanOrEqualTo(4));
    });
  }

  test('same seed gives the same level', () {
    final a = LevelGenerator.generate(Difficulty.hard, seed: 42);
    final b = LevelGenerator.fromSeed(Difficulty.hard, 42);
    expect(a.solution, b.solution);
  });
}
