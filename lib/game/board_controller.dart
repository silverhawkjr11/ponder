import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

/// What the chess board widget needs from whoever drives it: a puzzle
/// session or a full game against the engine.
abstract class BoardController extends ChangeNotifier {
  Position get pos;
  Side get userSide;
  Square? get selected;
  NormalMove? get lastMove;
  NormalMove? get wrongMove;
  Square? get hintFrom;
  bool get hintFull;
  NormalMove? get expected;
  NormalMove? get pendingPromotion;
  bool get solved; // drives the "done" glow
  bool get userTurn;
  Square? get checkedKing => pos.isCheck ? pos.board.kingOf(pos.turn) : null;
  Set<Square> destinations(Square from);
  void tap(Square sq);
  void promote(Role role);
  void cancelPromotion();
}
