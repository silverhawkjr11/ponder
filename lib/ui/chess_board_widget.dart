import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../game/chess_session.dart';
import '../theme/mocha.dart';

class ChessBoardWidget extends StatelessWidget {
  final ChessSession session;
  const ChessBoardWidget({super.key, required this.session});

  static const light = Color(0xFF6C7086);
  static const dark = Color(0xFF45475A);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) => LayoutBuilder(
        builder: (context, c) {
          final side = c.biggest.shortestSide;
          final sq = side / 8;
          final flipped = session.userSide == Side.black;
          Offset originOf(Square s) {
            final file = flipped ? 7 - s.file : s.file;
            final rank = flipped ? s.rank : 7 - s.rank;
            return Offset(file * sq, rank * sq);
          }

          Square squareAt(Offset local) {
            var file = (local.dx / sq).floor().clamp(0, 7);
            var rank = 7 - (local.dy / sq).floor().clamp(0, 7);
            if (flipped) {
              file = 7 - file;
              rank = 7 - rank;
            }
            return Square.fromCoords(File(file), Rank(rank));
          }

          final sel = session.selected;
          final dests = sel != null ? session.destinations(sel) : const <Square>{};
          final pieces = <Widget>[];
          for (final entry in session.pos.board.pieces) {
            final (square, piece) = entry;
            final o = originOf(square);
            pieces.add(
              AnimatedPositioned(
                key: ValueKey('${piece.color.name}${piece.role.name}${square.name}'),
                duration: const Duration(milliseconds: 1),
                left: o.dx,
                top: o.dy,
                width: sq,
                height: sq,
                child: IgnorePointer(
                  child: SvgPicture.asset(
                    'assets/pieces/${piece.color == Side.white ? 'w' : 'b'}${_letter(piece.role)}.svg',
                  ),
                ),
              ),
            );
          }

          return GestureDetector(
            onTapUp: (d) {
              if (session.pendingPromotion != null) return;
              session.tap(squareAt(d.localPosition));
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(sq * 0.22),
              child: SizedBox(
                width: side,
                height: side,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size(side, side),
                      painter: _SquaresPainter(
                        session: session,
                        flipped: flipped,
                        originOf: originOf,
                        dests: dests,
                      ),
                    ),
                    ...pieces,
                    if (session.pendingPromotion != null)
                      _PromotionPicker(session: session, square: sq),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _letter(Role r) => switch (r) {
    Role.king => 'K',
    Role.queen => 'Q',
    Role.rook => 'R',
    Role.bishop => 'B',
    Role.knight => 'N',
    Role.pawn => 'P',
  };
}

class _SquaresPainter extends CustomPainter {
  final ChessSession session;
  final bool flipped;
  final Offset Function(Square) originOf;
  final Set<Square> dests;
  _SquaresPainter({
    required this.session,
    required this.flipped,
    required this.originOf,
    required this.dests,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sq = size.width / 8;
    final paint = Paint();
    for (var i = 0; i < 64; i++) {
      final s = Square(i);
      final o = originOf(s);
      paint.color = (s.file + s.rank).isEven ? ChessBoardWidget.dark : ChessBoardWidget.light;
      canvas.drawRect(Rect.fromLTWH(o.dx, o.dy, sq, sq), paint);
    }
    void tint(Square s, Color c) {
      final o = originOf(s);
      canvas.drawRect(Rect.fromLTWH(o.dx, o.dy, sq, sq), Paint()..color = c);
    }

    final last = session.lastMove;
    if (last != null) {
      tint(last.from, Mocha.yellow.withValues(alpha: 0.28));
      tint(last.to, Mocha.yellow.withValues(alpha: 0.36));
    }
    final king = session.checkedKing;
    if (king != null) {
      final o = originOf(king);
      canvas.drawCircle(
        o + Offset(sq / 2, sq / 2),
        sq * 0.55,
        Paint()
          ..shader = RadialGradient(
            colors: [Mocha.red.withValues(alpha: 0.75), Mocha.red.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: o + Offset(sq / 2, sq / 2), radius: sq * 0.55)),
      );
    }
    final wrong = session.wrongMove;
    if (wrong != null) {
      tint(wrong.from, Mocha.red.withValues(alpha: 0.35));
      tint(wrong.to, Mocha.red.withValues(alpha: 0.5));
    }
    final hint = session.hintFrom;
    if (hint != null) tint(hint, Mocha.green.withValues(alpha: 0.45));
    if (session.hintFull && session.expected != null) {
      tint(session.expected!.to, Mocha.green.withValues(alpha: 0.45));
    }
    final sel = session.selected;
    if (sel != null) tint(sel, Mocha.mauve.withValues(alpha: 0.45));
    for (final d in dests) {
      final o = originOf(d) + Offset(sq / 2, sq / 2);
      final capture = session.pos.board.pieceAt(d) != null;
      if (capture) {
        canvas.drawCircle(
          o,
          sq * 0.44,
          Paint()
            ..color = Mocha.crust.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = sq * 0.1,
        );
      } else {
        canvas.drawCircle(o, sq * 0.15, Paint()..color = Mocha.crust.withValues(alpha: 0.35));
      }
    }

    // Coordinates.
    final style = TextStyle(
      fontSize: sq * 0.2,
      fontWeight: FontWeight.w800,
      fontFamily: 'Nunito',
    );
    for (var i = 0; i < 8; i++) {
      final fileSq = Square.fromCoords(File(i), Rank(flipped ? 7 : 0));
      final rankSq = Square.fromCoords(File(flipped ? 7 : 0), Rank(i));
      final fo = originOf(fileSq);
      final ro = originOf(rankSq);
      final fileColor = (fileSq.file + fileSq.rank).isEven ? ChessBoardWidget.light : ChessBoardWidget.dark;
      final rankColor = (rankSq.file + rankSq.rank).isEven ? ChessBoardWidget.light : ChessBoardWidget.dark;
      final tpF = TextPainter(
        text: TextSpan(text: 'abcdefgh'[i], style: style.copyWith(color: fileColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      tpF.paint(canvas, Offset(fo.dx + sq - tpF.width - sq * 0.06, fo.dy + sq - tpF.height - sq * 0.02));
      final tpR = TextPainter(
        text: TextSpan(text: '${i + 1}', style: style.copyWith(color: rankColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      tpR.paint(canvas, Offset(ro.dx + sq * 0.06, ro.dy + sq * 0.02));
    }
  }

  @override
  bool shouldRepaint(covariant _SquaresPainter old) => true;
}

class _PromotionPicker extends StatelessWidget {
  final ChessSession session;
  final double square;
  const _PromotionPicker({required this.session, required this.square});

  @override
  Widget build(BuildContext context) {
    final w = session.userSide == Side.white ? 'w' : 'b';
    return Positioned.fill(
      child: GestureDetector(
        onTap: session.cancelPromotion,
        child: Container(
          color: Mocha.crust.withValues(alpha: 0.6),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Mocha.mantle,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (role, letter) in [
                  (Role.queen, 'Q'),
                  (Role.rook, 'R'),
                  (Role.bishop, 'B'),
                  (Role.knight, 'N'),
                ])
                  GestureDetector(
                    onTap: () => session.promote(role),
                    child: SizedBox(
                      width: square * 1.2,
                      height: square * 1.2,
                      child: SvgPicture.asset('assets/pieces/$w$letter.svg'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
