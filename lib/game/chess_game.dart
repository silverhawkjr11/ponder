import 'package:dartchess/dartchess.dart';

import 'board_controller.dart';
import 'engine.dart';

enum GameOutcome { win, loss, draw }

class GameResult {
  final GameOutcome outcome;
  final String reason;
  const GameResult(this.outcome, this.reason);
}

/// A full game against the engine.
class ChessGame extends BoardController {
  final EnginePort engine;
  final EngineLevel level;
  @override
  final Side userSide;
  @override
  Position pos = Chess.initial;
  final List<NormalMove> moves = [];
  final List<String> sans = [];
  final Map<String, int> _seen = {};
  bool thinking = false;
  GameResult? result;
  int hintsUsed = 0;
  int undos = 0;
  bool _disposed = false;
  int _gen = 0;

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
  @override
  NormalMove? expected;
  @override
  NormalMove? pendingPromotion;

  ChessGame({
    required this.engine,
    required this.level,
    required this.userSide,
    List<String>? resumeMoves,
    int hints = 0,
  }) {
    hintsUsed = hints;
    _note();
    for (final u in resumeMoves ?? const []) {
      final m = Move.parse(u);
      if (m is! NormalMove || !pos.isLegal(m)) break;
      _apply(m);
    }
    _checkOver();
    if (result == null && pos.turn != userSide) _engineMove();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  bool get solved => result != null;
  @override
  bool get userTurn => result == null && !thinking && pos.turn == userSide;
  bool get over => result != null;

  Map<String, dynamic> toJson() => {
    'level': level.number,
    'side': userSide.name,
    'moves': [for (final m in moves) m.uci],
    'hints': hintsUsed,
  };

  /// Material balance from the user's point of view, in pawns.
  int get materialBalance {
    int value(Role r) => switch (r) {
      Role.pawn => 1,
      Role.knight || Role.bishop => 3,
      Role.rook => 5,
      Role.queen => 9,
      Role.king => 0,
    };
    var total = 0;
    for (final (_, piece) in pos.board.pieces) {
      final v = value(piece.role);
      total += piece.color == userSide ? v : -v;
    }
    return total;
  }

  @override
  Set<Square> destinations(Square from) =>
      userTurn ? pos.legalMovesOf(from).squares.toSet() : const {};

  @override
  void tap(Square sq) {
    if (!userTurn) return;
    final sel = selected;
    if (sel != null && destinations(sel).contains(sq)) {
      final piece = pos.board.pieceAt(sel);
      if (piece?.role == Role.pawn && (sq.rank == 0 || sq.rank == 7)) {
        pendingPromotion = NormalMove(from: sel, to: sq);
        selected = null;
        notifyListeners();
        return;
      }
      _userMove(NormalMove(from: sel, to: sq));
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
    _userMove(p.withPromotion(role));
  }

  @override
  void cancelPromotion() {
    pendingPromotion = null;
    notifyListeners();
  }

  void _userMove(NormalMove m) {
    selected = null;
    hintFrom = null;
    hintFull = false;
    expected = null;
    _apply(m);
    _checkOver();
    notifyListeners();
    if (result == null) _engineMove();
  }

  void _apply(NormalMove m) {
    final (next, san) = pos.makeSan(m);
    pos = next;
    moves.add(m);
    sans.add(san);
    lastMove = m;
    _note();
  }

  void _note() {
    final key = pos.fen.split(' ').take(4).join(' ');
    _seen[key] = (_seen[key] ?? 0) + 1;
  }

  Future<void> _engineMove() async {
    final gen = ++_gen;
    thinking = true;
    notifyListeners();
    final uci = await engine.bestMove(pos.fen, level);
    if (_disposed || gen != _gen) return;
    thinking = false;
    final m = uci == null ? null : Move.parse(uci);
    if (m is NormalMove && pos.isLegal(m)) {
      _apply(m);
    }
    _checkOver();
    notifyListeners();
  }

  void _checkOver() {
    if (result != null) return;
    if (pos.isCheckmate) {
      final winner = pos.turn.opposite;
      result = GameResult(winner == userSide ? GameOutcome.win : GameOutcome.loss, 'Checkmate');
    } else if (pos.isStalemate) {
      result = const GameResult(GameOutcome.draw, 'Stalemate');
    } else if (pos.isInsufficientMaterial) {
      result = const GameResult(GameOutcome.draw, 'Insufficient material');
    } else if (pos.halfmoves >= 100) {
      result = const GameResult(GameOutcome.draw, 'Fifty-move rule');
    } else if ((_seen[pos.fen.split(' ').take(4).join(' ')] ?? 0) >= 3) {
      result = const GameResult(GameOutcome.draw, 'Threefold repetition');
    }
  }

  void resign() {
    if (result != null) return;
    _gen++;
    thinking = false;
    result = const GameResult(GameOutcome.loss, 'Resigned');
    notifyListeners();
  }

  /// Takes back the last user move (and the engine's reply).
  void undo() {
    if (result != null && result!.reason == 'Resigned') return;
    if (thinking || moves.isEmpty) return;
    final take = pos.turn == userSide ? 2 : 1;
    final kept = moves.take(moves.length - take.clamp(1, moves.length)).map((m) => m.uci).toList();
    _gen++;
    pos = Chess.initial;
    moves.clear();
    sans.clear();
    _seen.clear();
    _note();
    lastMove = null;
    result = null;
    selected = null;
    hintFrom = null;
    hintFull = false;
    expected = null;
    for (final u in kept) {
      _apply(Move.parse(u)! as NormalMove);
    }
    undos++;
    notifyListeners();
    if (pos.turn != userSide) _engineMove();
  }

  Future<void> hint() async {
    if (!userTurn) return;
    if (expected == null) {
      final gen = _gen;
      final uci = await engine.analyse(pos.fen);
      if (_disposed || gen != _gen || !userTurn) return;
      final m = uci == null ? null : Move.parse(uci);
      if (m is! NormalMove) return;
      expected = m;
      hintFrom = m.from;
      selected = m.from;
    } else {
      hintFull = true;
    }
    hintsUsed++;
    notifyListeners();
  }
}
