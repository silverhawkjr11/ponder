import 'package:connect_the_dots/game/level.dart';
import 'package:connect_the_dots/game/sudoku.dart';
import 'package:flutter_test/flutter_test.dart';

bool validSolution(List<int> g) {
  for (var r = 0; r < 9; r++) {
    final row = <int>{}, col = <int>{}, box = <int>{};
    for (var k = 0; k < 9; k++) {
      row.add(g[r * 9 + k]);
      col.add(g[k * 9 + r]);
      box.add(g[((r ~/ 3) * 3 + k ~/ 3) * 9 + (r % 3) * 3 + k % 3]);
    }
    if (row.length != 9 || col.length != 9 || box.length != 9) return false;
  }
  return g.every((v) => v >= 1 && v <= 9);
}

void main() {
  test('generates valid puzzles near the clue target', () {
    for (final d in Difficulty.values) {
      final sw = Stopwatch()..start();
      for (var seed = 0; seed < 4; seed++) {
        final l = SudokuGenerator.generate(d, seed: seed);
        expect(validSolution(l.solution), isTrue);
        for (var i = 0; i < 81; i++) {
          if (l.givens[i] != 0) expect(l.givens[i], l.solution[i]);
        }
        expect(l.clueCount, lessThanOrEqualTo(d.sudokuClues + 4));
      }
      // ignore: avoid_print
      print('${d.label}: 4 sudokus in ${sw.elapsedMilliseconds}ms');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('board tracks mistakes, notes, undo and win', () {
    final l = SudokuGenerator.generate(Difficulty.easy, seed: 5);
    final b = SudokuBoard(l);
    final empty = l.givens.indexOf(0);
    b.select(empty);
    final right = l.solution[empty];
    final wrong = right == 9 ? 1 : right + 1;
    b.enter(wrong);
    expect(b.mistakes, 1);
    expect(b.isWrong(empty), isTrue);
    b.undo();
    expect(b.values[empty], 0);
    b.togglePencil();
    b.enter(3);
    expect(b.notes[empty], {3});
    b.togglePencil();
    b.enter(right);
    expect(b.values[empty], right);
    expect(b.notes[empty], isEmpty);
    // Fill the rest via hints.
    while (!b.won) {
      expect(b.hint(), isTrue);
    }
    expect(b.won, isTrue);
  });
}
