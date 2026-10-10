import 'package:connect_the_dots/game/chess_puzzle.dart';
import 'package:connect_the_dots/game/chess_session.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const line =
      '00008;r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2R1/PqP2bPP/7K b - - 0 24;f2g3 e6e7 b2b1 b3c1 b1c1 h6c1;1811;hangingPiece';

  test('parses a puzzle line', () {
    final p = ChessPuzzle.parse(line)!;
    expect(p.id, '00008');
    expect(p.moves.length, 6);
    expect(p.rating, 1811);
    expect(ChessPuzzle.themeLabel('mateIn2'), 'Mate in 2');
    expect(ChessPuzzle.themeLabel('hangingPiece'), 'Hanging piece');
  });

  test('plays through the solution with replies', () {
    fakeAsync((async) {
      final s = ChessSession(ChessPuzzle.parse(line)!);
      expect(s.userSide, Side.white);
      expect(s.userTurn, isFalse);
      async.elapse(const Duration(seconds: 1));
      expect(s.userTurn, isTrue);
      expect(s.lastMove!.uci, 'f2g3');
      // Wrong move first.
      s.tap(Square.fromName('e6'));
      s.tap(Square.fromName('e5'));
      expect(s.wrongCount, 1);
      expect(s.step, 1);
      // Correct move.
      s.tap(Square.fromName('e6'));
      s.tap(Square.fromName('e7'));
      expect(s.step, 2);
      expect(s.state, PuzzleState.replying);
      async.elapse(const Duration(seconds: 1));
      expect(s.lastMove!.uci, 'b2b1');
      s.tap(Square.fromName('b3'));
      s.tap(Square.fromName('c1'));
      async.elapse(const Duration(seconds: 1));
      s.tap(Square.fromName('h6'));
      s.tap(Square.fromName('c1'));
      expect(s.solved, isTrue);
      expect(s.clean, isFalse);
      s.dispose();
    });
  });

  test('promotion asks for a piece', () {
    fakeAsync((async) {
      // White pawn on g7, black king a8, white king h1; black plays Ka7, white promotes.
      final p = ChessPuzzle(
        id: 'x',
        fen: 'k7/6P1/8/8/8/8/8/7K b - - 0 1',
        moves: const ['a8a7', 'g7g8q'],
        rating: 800,
        themes: const [],
      );
      final s = ChessSession(p);
      async.elapse(const Duration(seconds: 1));
      s.tap(Square.fromName('g7'));
      s.tap(Square.fromName('g8'));
      expect(s.pendingPromotion, isNotNull);
      s.promote(Role.queen);
      expect(s.solved, isTrue);
      s.dispose();
    });
  });
}
