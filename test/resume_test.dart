import 'package:connect_the_dots/game/board.dart';
import 'package:connect_the_dots/game/chess_puzzle.dart';
import 'package:connect_the_dots/game/chess_session.dart';
import 'package:connect_the_dots/game/generator.dart';
import 'package:connect_the_dots/game/level.dart';
import 'package:connect_the_dots/game/sudoku.dart';
import 'package:connect_the_dots/game/zip_board.dart';
import 'package:connect_the_dots/game/zip_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flow board round-trips through json', () {
    final level = LevelGenerator.generate(Difficulty.easy, seed: 3);
    final a = Board(level);
    final p = level.solution[0];
    a.beginDrag(p.first);
    for (final c in p.skip(1)) {
      a.dragTo(c);
    }
    a.endDrag();
    a.hint();
    final json = a.toJson();
    final b = Board(LevelGenerator.generate(Difficulty.easy, seed: 3))..restore(json);
    expect(b.isComplete(0), isTrue);
    expect(b.completedCount, a.completedCount);
    expect(b.moves, a.moves);
    expect(b.hintsUsed, 1);
  });

  test('zip board round-trips through json', () {
    final level = ZipGenerator.generate(Difficulty.easy, seed: 3);
    final a = ZipBoard(level);
    a.beginDrag(level.solution[1]);
    a.dragTo(level.solution[2]);
    a.dragTo(level.solution[3]);
    a.endDrag();
    final b = ZipBoard(ZipGenerator.generate(Difficulty.easy, seed: 3))..restore(a.toJson());
    expect(b.path, a.path);
    expect(b.moves, 1);
  });

  test('sudoku board round-trips through json', () {
    final level = SudokuGenerator.generate(Difficulty.easy, seed: 9);
    final a = SudokuBoard(level);
    final i = level.givens.indexOf(0);
    a.select(i);
    a.togglePencil();
    a.enter(4);
    a.enter(7);
    a.togglePencil();
    final j = level.givens.indexOf(0, i + 1);
    a.select(j);
    a.enter(level.solution[j]);
    final b = SudokuBoard(SudokuGenerator.generate(Difficulty.easy, seed: 9))..restore(a.toJson());
    expect(b.notes[i], {4, 7});
    expect(b.values[j], level.solution[j]);
    expect(b.mistakes, a.mistakes);
  });

  test('chess session resumes at a user turn', () {
    final p = ChessPuzzle.parse(
      '00008;r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2R1/PqP2bPP/7K b - - 0 24;f2g3 e6e7 b2b1 b3c1 b1c1 h6c1;1811;hangingPiece',
    )!;
    final s = ChessSession(p, resumeStep: 3, wrong: 1, hints: 0);
    expect(s.step, 3);
    expect(s.userTurn, isTrue);
    expect(s.lastMove!.uci, 'b2b1');
    expect(s.wrongCount, 1);
    s.dispose();
    // Even step (opponent to reply) rewinds to the previous user turn.
    final t = ChessSession(p, resumeStep: 2);
    expect(t.step, 1);
    t.dispose();
  });
}
