import 'package:connect_the_dots/game/generator.dart';
import 'package:connect_the_dots/game/level.dart';
import 'package:connect_the_dots/game/solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('solver counts the two mirrored solutions of a loose puzzle', () {
    // 3x3, one pair in opposite corners: two serpentines fill the grid.
    const l = Level(
      size: 3,
      difficulty: Difficulty.easy,
      seed: 0,
      solution: [
        [
          Cell(0, 0), Cell(0, 1), Cell(0, 2),
          Cell(1, 2), Cell(1, 1), Cell(1, 0),
          Cell(2, 0), Cell(2, 1), Cell(2, 2),
        ],
      ],
    );
    expect(FlowSolver(l).count(limit: 5), 2);
  });

  test('generated easy and medium levels have exactly one solution', () {
    for (final d in [Difficulty.easy, Difficulty.medium]) {
      for (var seed = 0; seed < 40; seed++) {
        final l = LevelGenerator.generate(d, seed: seed);
        expect(FlowSolver(l, budget: 2000000).count(limit: 2), 1,
            reason: '${d.label} seed $seed');
      }
    }
  });

  test('solution paths never touch themselves', () {
    for (final d in Difficulty.values) {
      for (var seed = 0; seed < 10; seed++) {
        final l = LevelGenerator.generate(d, seed: seed);
        for (final p in l.solution) {
          for (var i = 0; i < p.length; i++) {
            for (var j = i + 2; j < p.length; j++) {
              expect(p[i].isAdjacent(p[j]), isFalse,
                  reason: '${d.label} seed $seed');
            }
          }
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
