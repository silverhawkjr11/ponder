import 'package:connect_the_dots/game/level.dart';
import 'package:connect_the_dots/game/zip_board.dart';
import 'package:connect_the_dots/game/zip_generator.dart';
import 'package:connect_the_dots/game/zip_level.dart';
import 'package:connect_the_dots/game/zip_solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated zip levels are unique and consistent', () {
    for (final d in Difficulty.values) {
      for (var seed = 0; seed < 12; seed++) {
        final l = ZipGenerator.generate(d, seed: seed);
        expect(l.solution.length, l.size * l.size);
        expect(l.solution.toSet().length, l.size * l.size);
        for (var i = 1; i < l.solution.length; i++) {
          expect(l.solution[i].isAdjacent(l.solution[i - 1]), isTrue);
          expect(l.hasWall(l.solution[i], l.solution[i - 1]), isFalse);
        }
        expect(l.waypoints.first, l.solution.first);
        expect(l.waypoints.last, l.solution.last);
        expect(ZipSolver(l, budget: 3000000).count(limit: 2), 1,
            reason: '${d.label} seed $seed');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('zip board enforces order, walls and the final number', () {
    final l = ZipLevel(
      size: 3,
      difficulty: Difficulty.easy,
      seed: 0,
      solution: const [
        Cell(0, 0), Cell(0, 1), Cell(0, 2),
        Cell(1, 2), Cell(1, 1), Cell(1, 0),
        Cell(2, 0), Cell(2, 1), Cell(2, 2),
      ],
      waypoints: const [Cell(0, 0), Cell(1, 2), Cell(2, 2)],
      walls: {ZipLevel.wallKey(3, const Cell(0, 0), const Cell(1, 0))},
    );
    final b = ZipBoard(l);
    expect(b.path.length, 1);
    expect(b.beginDrag(const Cell(1, 0)), isFalse); // wall
    expect(b.beginDrag(const Cell(0, 1)), isTrue);
    b.dragTo(const Cell(0, 2));
    b.dragTo(const Cell(1, 2)); // number 2, in order
    expect(b.reached, 2);
    b.dragTo(const Cell(2, 2)); // number 3 too early
    expect(b.head, const Cell(1, 2));
    b.dragTo(const Cell(1, 0)); // straight line through (1,1)
    b.dragTo(const Cell(2, 0));
    b.dragTo(const Cell(2, 2));
    expect(b.won, isTrue);
  });

  test('backtracking and hint', () {
    final l = ZipGenerator.generate(Difficulty.easy, seed: 1);
    final b = ZipBoard(l);
    b.beginDrag(l.solution[1]);
    b.dragTo(l.solution[0]);
    expect(b.path.length, 1);
    b.endDrag();
    expect(b.hint(), isTrue);
    expect(b.reached, 2);
    expect(b.path, l.solution.sublist(0, b.path.length));
  });
}
