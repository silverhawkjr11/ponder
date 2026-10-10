import 'package:connect_the_dots/game/board.dart';
import 'package:connect_the_dots/game/level.dart';
import 'package:flutter_test/flutter_test.dart';

Level tiny() => const Level(
  size: 3,
  difficulty: Difficulty.easy,
  seed: 0,
  solution: [
    [Cell(0, 0), Cell(0, 1), Cell(0, 2), Cell(1, 2), Cell(2, 2)],
    [Cell(1, 0), Cell(2, 0), Cell(2, 1), Cell(1, 1)],
  ],
);

void main() {
  test('drawing the solution wins', () {
    final b = Board(tiny());
    for (var i = 0; i < 2; i++) {
      final p = tiny().solution[i];
      expect(b.beginDrag(p.first), isTrue);
      for (final c in p.skip(1)) {
        b.dragTo(c);
      }
      b.endDrag();
      expect(b.isComplete(i), isTrue);
    }
    expect(b.won, isTrue);
    expect(b.moves, 2);
  });

  test('cannot start from an empty cell or pass through another dot', () {
    final b = Board(tiny());
    expect(b.beginDrag(const Cell(2, 1)), isFalse);
    b.beginDrag(const Cell(0, 0));
    b.dragTo(const Cell(1, 0)); // other color's dot
    expect(b.pathOf(0).length, 1);
    expect(b.ownerAt(const Cell(1, 0)), 1);
  });

  test('another pipe blocks instead of being cut', () {
    final b = Board(tiny());
    b.beginDrag(const Cell(1, 0));
    b.dragTo(const Cell(2, 0));
    b.dragTo(const Cell(2, 1));
    b.dragTo(const Cell(1, 1));
    b.endDrag();
    expect(b.isComplete(1), isTrue);
    b.beginDrag(const Cell(2, 2));
    b.dragTo(const Cell(2, 1));
    expect(b.pathOf(0).length, 1);
    expect(b.isComplete(1), isTrue);
    expect(b.ownerAt(const Cell(2, 1)), 1);
  });

  test('backtracking trims and fast straight drags fill in cells', () {
    final b = Board(tiny());
    b.beginDrag(const Cell(0, 0));
    b.dragTo(const Cell(0, 2)); // skipped (0,1)
    expect(b.pathOf(0), [const Cell(0, 0), const Cell(0, 1), const Cell(0, 2)]);
    b.dragTo(const Cell(0, 0));
    expect(b.pathOf(0).length, 1);
    expect(b.ownerAt(const Cell(0, 1)), -1);
  });

  test('hint completes a color and restart clears everything', () {
    final b = Board(tiny());
    expect(b.hint(), isTrue);
    expect(b.completedCount, 1);
    b.restart();
    expect(b.completedCount, 0);
    expect(b.moves, 0);
    expect(b.filledCount, 4);
  });

  test('relaxed rule wins once every pair is joined', () {
    final b = Board(tiny(), requireFill: false);
    // Red: a shortcut that leaves (0,1),(0,2),(1,2) empty is still a win.
    b.beginDrag(const Cell(1, 0));
    b.dragTo(const Cell(2, 0));
    b.dragTo(const Cell(2, 1));
    b.dragTo(const Cell(1, 1));
    b.endDrag();
    b.beginDrag(const Cell(0, 0));
    b.dragTo(const Cell(0, 2));
    b.dragTo(const Cell(2, 2));
    expect(b.won, isTrue);
  });
}
