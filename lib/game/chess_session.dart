import 'dart:async';

import 'package:dartchess/dartchess.dart';

import 'board_controller.dart';
import 'chess_puzzle.dart';

enum PuzzleState { intro, thinking, replying, solved }

/// Drives one puzzle: plays the opponent's setup move, checks each of the
/// player's moves against the solution and plays the replies.
class ChessSession extends BoardController {
  final ChessPuzzle puzzle;
  @override
  late Position pos;
  late final List<NormalMove> line;
  @override
  late final Side userSide;
  int step = 0;
  PuzzleState state = PuzzleState.intro;
  @override
  Square? selected;
  @override
  NormalMove? lastMove;
  @override
  NormalMove? wrongMove;
  @override
  Square? hintFrom;
  @override
  bool hintFull = false;
  int wrongCount = 0;
  int hintsUsed = 0;
  @override
  NormalMove? pendingPromotion; // from/to awaiting a piece choice
  final bool autoQueen;
  Timer? _timer;

  ChessSession(this.puzzle, {this.autoQueen = false, int resumeStep = 0, int wrong = 0, int hints = 0}) {
    pos = Chess.fromSetup(Setup.parseFen(puzzle.fen));
    line = [for (final m in puzzle.moves) Move.parse(m)! as NormalMove];
    userSide = pos.turn.opposite;
    if (resumeStep > 0 && resumeStep < line.length) {
      // Replay instantly up to where the player left off (always a user turn).
      final target = resumeStep.isOdd ? resumeStep : resumeStep - 1;
      for (var i = 0; i < target; i++) {
        pos = pos.play(line[i]);
        lastMove = line[i];
      }
      step = target;
      wrongCount = wrong;
      hintsUsed = hints;
      state = PuzzleState.thinking;
    } else {
      _timer = Timer(const Duration(milliseconds: 700), _playReply);
    }
  }

  Map<String, dynamic> toJson() => {
    'id': puzzle.id,
    'step': step,
    'wrong': wrongCount,
    'hints': hintsUsed,
  };

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  bool get userTurn =>
      state == PuzzleState.thinking && step < line.length && pos.turn == userSide;
  @override
  bool get solved => state == PuzzleState.solved;
  bool get clean => wrongCount == 0 && hintsUsed == 0;
  @override
  NormalMove? get expected => step < line.length ? line[step] : null;
  @override
  Set<Square> destinations(Square from) =>
      userTurn ? pos.legalMovesOf(from).squares.toSet() : const {};

  void _playReply() {
    if (step >= line.length) return;
    final m = line[step];
    pos = pos.play(m);
    lastMove = m;
    step++;
    state = step >= line.length ? PuzzleState.solved : PuzzleState.thinking;
    notifyListeners();
  }

  @override
  void tap(Square sq) {
    if (!userTurn) return;
    wrongMove = null;
    final sel = selected;
    if (sel != null && destinations(sel).contains(sq)) {
      final piece = pos.board.pieceAt(sel);
      final promo = piece?.role == Role.pawn && (sq.rank == 0 || sq.rank == 7);
      if (promo && !autoQueen) {
        pendingPromotion = NormalMove(from: sel, to: sq);
        selected = null;
        notifyListeners();
        return;
      }
      if (promo) {
        _attempt(NormalMove(from: sel, to: sq, promotion: Role.queen));
        return;
      }
      _attempt(NormalMove(from: sel, to: sq));
      return;
    }
    final piece = pos.board.pieceAt(sq);
    selected = piece != null && piece.color == userSide ? sq : null;
    notifyListeners();
  }

  @override
  void promote(Role role) {
    final p = pendingPromotion;
    if (p == null) return;
    pendingPromotion = null;
    _attempt(p.withPromotion(role));
  }

  @override
  void cancelPromotion() {
    pendingPromotion = null;
    notifyListeners();
  }

  void _attempt(NormalMove move) {
    final exp = line[step];
    final next = pos.play(move);
    final ok = move == exp || next.isCheckmate;
    if (!ok) {
      wrongCount++;
      wrongMove = move;
      selected = null;
      notifyListeners();
      return;
    }
    pos = next;
    lastMove = move;
    step++;
    selected = null;
    hintFrom = null;
    hintFull = false;
    if (step >= line.length || next.isCheckmate) {
      state = PuzzleState.solved;
      notifyListeners();
      return;
    }
    state = PuzzleState.replying;
    notifyListeners();
    _timer = Timer(const Duration(milliseconds: 450), _playReply);
  }

  /// First hint marks the piece, second shows the whole move.
  void hint() {
    if (!userTurn) return;
    final exp = expected;
    if (exp == null) return;
    if (hintFrom == null) {
      hintFrom = exp.from;
      selected = exp.from;
    } else {
      hintFull = true;
    }
    hintsUsed++;
    notifyListeners();
  }

  void retry() {
    _timer?.cancel();
    pos = Chess.fromSetup(Setup.parseFen(puzzle.fen));
    step = 0;
    state = PuzzleState.intro;
    selected = null;
    lastMove = null;
    wrongMove = null;
    hintFrom = null;
    hintFull = false;
    pendingPromotion = null;
    notifyListeners();
    _timer = Timer(const Duration(milliseconds: 500), _playReply);
  }
}
