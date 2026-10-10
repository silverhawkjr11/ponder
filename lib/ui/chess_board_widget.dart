import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../game/chess_session.dart';
import '../theme/palette.dart';

/// Animated chess board: pieces slide, captures fade, selection lifts the
/// piece, wrong moves shake the board, check pulses, and the solved line glows.
class ChessBoardWidget extends StatefulWidget {
  final ChessSession session;
  const ChessBoardWidget({super.key, required this.session});

  static Color get light => Pal.p.light
      ? Pal.surface1
      : Color.lerp(Pal.overlay0, Pal.lavender, 0.08)!;
  static Color get dark => Pal.p.light
      ? Pal.overlay0
      : Color.lerp(Pal.surface1, Pal.lavender, 0.04)!;

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _PieceView {
  final String id;
  final Piece piece;
  Square square;
  bool captured = false;
  _PieceView(this.id, this.piece, this.square);
}

class _ChessBoardWidgetState extends State<ChessBoardWidget>
    with TickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();
  late final AnimationController _solve = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  final Map<Square, _PieceView> _views = {};
  final List<_PieceView> _ghosts = [];
  int _nextId = 0;
  NormalMove? _seenMove;
  bool _seenSolved = false;

  @override
  void initState() {
    super.initState();
    _syncPieces(initial: true);
    widget.session.addListener(_onSession);
    _onSession();
  }

  @override
  void didUpdateWidget(covariant ChessBoardWidget old) {
    super.didUpdateWidget(old);
    if (old.session != widget.session) {
      old.session.removeListener(_onSession);
      widget.session.addListener(_onSession);
      _views.clear();
      _ghosts.clear();
      _seenMove = null;
      _seenSolved = false;
      _solve.reset();
      _intro.forward(from: 0);
      _syncPieces(initial: true);
      _onSession();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _shake.dispose();
    _pulse.dispose();
    _intro.dispose();
    _solve.dispose();
    super.dispose();
  }

  void _onSession() {
    final s = widget.session;
    if (s.lastMove != _seenMove) {
      _seenMove = s.lastMove;
      _syncPieces();
    } else if (s.lastMove == null &&
        _views.length != s.pos.board.occupied.size) {
      _syncPieces(initial: true); // retry reset the position
    }
    if (s.wrongMove != null && !_shake.isAnimating) _shake.forward(from: 0);
    if (s.pos.isCheck && !s.solved) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
    if (s.solved && !_seenSolved) {
      _seenSolved = true;
      _solve.forward(from: 0);
    } else if (!s.solved && _seenSolved) {
      _seenSolved = false;
      _solve.reset();
    }
    if (mounted) setState(() {});
  }

  /// Keeps stable ids per piece so moved pieces animate instead of popping.
  void _syncPieces({bool initial = false}) {
    final board = widget.session.pos.board;
    final move = widget.session.lastMove;
    if (initial) {
      _views.clear();
      _ghosts.clear();
      for (final (sq, piece) in board.pieces) {
        _views[sq] = _PieceView('p${_nextId++}', piece, sq);
      }
      return;
    }
    final next = <Square, _PieceView>{};
    final remaining = Map.of(_views);
    // Pieces that stayed put.
    for (final (sq, piece) in board.pieces) {
      final v = remaining[sq];
      if (v != null && v.piece == piece) {
        next[sq] = v;
        remaining.remove(sq);
      }
    }
    // Pieces that moved (the mover, plus a castling rook).
    for (final (sq, piece) in board.pieces) {
      if (next.containsKey(sq)) continue;
      _PieceView? from;
      if (move != null && sq == move.to && remaining.containsKey(move.from)) {
        from = remaining.remove(move.from);
      } else {
        // Nearest same-colour, same-role piece that vanished.
        Square? bestSq;
        var best = 1 << 20;
        remaining.forEach((rs, rv) {
          if (rv.piece.color != piece.color || rv.piece.role != piece.role) {
            return;
          }
          final d = (rs.file - sq.file).abs() + (rs.rank - sq.rank).abs();
          if (d < best) {
            best = d;
            bestSq = rs;
          }
        });
        if (bestSq != null) from = remaining.remove(bestSq);
      }
      if (from != null) {
        from.square = sq;
        next[sq] = _PieceView(from.id, piece, sq);
      } else {
        next[sq] = _PieceView('p${_nextId++}', piece, sq);
      }
    }
    // Whatever is left was captured.
    for (final v in remaining.values) {
      v.captured = true;
      _ghosts.add(v);
    }
    _views
      ..clear()
      ..addAll(next);
    if (_ghosts.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() => _ghosts.removeWhere((g) => remaining.containsValue(g)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return LayoutBuilder(
      builder: (context, c) {
        final side = c.biggest.shortestSide;
        final frame = side * 0.025;
        final inner = side - frame * 2;
        final sq = inner / 8;
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
        final dests = sel != null
            ? session.destinations(sel)
            : const <Square>{};

        final pieceWidgets = <Widget>[
          for (final g in _ghosts)
            _Ghost(
              key: ValueKey('ghost${g.id}'),
              origin: originOf(g.square),
              size: sq,
              piece: g.piece,
            ),
          for (final v in _views.values)
            AnimatedPositioned(
              key: ValueKey(v.id),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              left: originOf(v.square).dx,
              top: originOf(v.square).dy,
              width: sq,
              height: sq,
              child: IgnorePointer(
                child: AnimatedScale(
                  scale: v.square == sel ? 1.12 : 1,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutBack,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: v.square == sel
                        ? BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Pal.crust.withValues(alpha: 0.45),
                                blurRadius: sq * 0.25,
                                offset: Offset(0, sq * 0.08),
                              ),
                            ],
                          )
                        : const BoxDecoration(),
                    child: _pieceSvg(v.piece),
                  ),
                ),
              ),
            ),
        ];

        return AnimatedBuilder(
          animation: Listenable.merge([_shake, _pulse, _intro, _solve]),
          builder: (context, child) {
            final shake = _shake.value;
            final dx = math.sin(shake * math.pi * 5) * 10 * (1 - shake);
            final intro = Curves.easeOutCubic.transform(_intro.value);
            return Opacity(
              opacity: intro,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.scale(
                  scale: 0.96 + 0.04 * intro,
                  child: Container(
                    width: side,
                    height: side,
                    padding: EdgeInsets.all(frame),
                    decoration: BoxDecoration(
                      color: Pal.mantle,
                      borderRadius: BorderRadius.circular(side * 0.045),
                      boxShadow: [
                        BoxShadow(
                          color: (session.solved ? Pal.green : Pal.mauve)
                              .withValues(
                                alpha: session.solved
                                    ? 0.25 * _solve.value
                                    : 0.10,
                              ),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Pal.crust.withValues(alpha: 0.5),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(side * 0.03),
                      child: GestureDetector(
                        onTapUp: (d) {
                          if (session.pendingPromotion != null) return;
                          session.tap(squareAt(d.localPosition));
                        },
                        child: Stack(
                          children: [
                            TweenAnimationBuilder<double>(
                              key: ValueKey(sel),
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutBack,
                              builder: (_, t, _) => CustomPaint(
                                size: Size(inner, inner),
                                painter: _SquaresPainter(
                                  session: session,
                                  flipped: flipped,
                                  originOf: originOf,
                                  dests: dests,
                                  destScale: t,
                                  pulse: _pulse.value,
                                  solve: _solve.value,
                                ),
                              ),
                            ),
                            ...pieceWidgets,
                            if (session.pendingPromotion != null)
                              _PromotionPicker(session: session, square: sq),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _pieceSvg(Piece piece) => SvgPicture.asset(
    'assets/pieces/${piece.color == Side.white ? 'w' : 'b'}${_letter(piece.role)}.svg',
  );

  static String _letter(Role r) => switch (r) {
    Role.king => 'K',
    Role.queen => 'Q',
    Role.rook => 'R',
    Role.bishop => 'B',
    Role.knight => 'N',
    Role.pawn => 'P',
  };
}

/// A captured piece shrinking and fading away.
class _Ghost extends StatelessWidget {
  final Offset origin;
  final double size;
  final Piece piece;
  const _Ghost({
    super.key,
    required this.origin,
    required this.size,
    required this.piece,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: origin.dx,
      top: origin.dy,
      width: size,
      height: size,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: 0),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeIn,
          builder: (_, t, child) => Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
          ),
          child: _ChessBoardWidgetState._pieceSvg(piece),
        ),
      ),
    );
  }
}

class _SquaresPainter extends CustomPainter {
  final ChessSession session;
  final bool flipped;
  final Offset Function(Square) originOf;
  final Set<Square> dests;
  final double destScale;
  final double pulse;
  final double solve;
  _SquaresPainter({
    required this.session,
    required this.flipped,
    required this.originOf,
    required this.dests,
    required this.destScale,
    required this.pulse,
    required this.solve,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sq = size.width / 8;
    final paint = Paint();
    for (var i = 0; i < 64; i++) {
      final s = Square(i);
      final o = originOf(s);
      paint.color = (s.file + s.rank).isEven
          ? ChessBoardWidget.dark
          : ChessBoardWidget.light;
      canvas.drawRect(Rect.fromLTWH(o.dx, o.dy, sq, sq), paint);
    }
    void tint(Square s, Color c) {
      final o = originOf(s);
      canvas.drawRect(Rect.fromLTWH(o.dx, o.dy, sq, sq), Paint()..color = c);
    }

    final last = session.lastMove;
    if (last != null) {
      final c = session.solved
          ? Color.lerp(Pal.yellow, Pal.green, solve)!
          : Pal.yellow;
      tint(last.from, c.withValues(alpha: 0.26));
      tint(last.to, c.withValues(alpha: 0.38));
    }
    final king = session.checkedKing;
    if (king != null) {
      final center = originOf(king) + Offset(sq / 2, sq / 2);
      final r = sq * (0.5 + 0.12 * pulse);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Pal.red.withValues(alpha: 0.7 + 0.2 * pulse),
              Pal.red.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
    final wrong = session.wrongMove;
    if (wrong != null) {
      tint(wrong.from, Pal.red.withValues(alpha: 0.35));
      tint(wrong.to, Pal.red.withValues(alpha: 0.5));
    }
    final hint = session.hintFrom;
    if (hint != null) tint(hint, Pal.green.withValues(alpha: 0.45));
    if (session.hintFull && session.expected != null) {
      final o = originOf(session.expected!.to);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(o.dx, o.dy, sq, sq).deflate(sq * 0.08),
          Radius.circular(sq * 0.18),
        ),
        Paint()
          ..color = Pal.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = sq * 0.08,
      );
    }
    final sel = session.selected;
    if (sel != null) tint(sel, Pal.mauve.withValues(alpha: 0.45));
    for (final d in dests) {
      final o = originOf(d) + Offset(sq / 2, sq / 2);
      final capture = session.pos.board.pieceAt(d) != null;
      if (capture) {
        canvas.drawCircle(
          o,
          sq * 0.44 * destScale,
          Paint()
            ..color = Pal.crust.withValues(alpha: 0.38)
            ..style = PaintingStyle.stroke
            ..strokeWidth = sq * 0.1,
        );
      } else {
        canvas.drawCircle(
          o,
          sq * 0.15 * destScale,
          Paint()..color = Pal.crust.withValues(alpha: 0.38),
        );
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
      final fileColor = (fileSq.file + fileSq.rank).isEven
          ? ChessBoardWidget.light
          : ChessBoardWidget.dark;
      final rankColor = (rankSq.file + rankSq.rank).isEven
          ? ChessBoardWidget.light
          : ChessBoardWidget.dark;
      final tpF = TextPainter(
        text: TextSpan(
          text: 'abcdefgh'[i],
          style: style.copyWith(color: fileColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpF.paint(
        canvas,
        Offset(
          fo.dx + sq - tpF.width - sq * 0.06,
          fo.dy + sq - tpF.height - sq * 0.02,
        ),
      );
      final tpR = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: style.copyWith(color: rankColor),
        ),
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
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          builder: (_, t, child) => Container(
            color: Pal.crust.withValues(alpha: 0.6 * t.clamp(0, 1)),
            alignment: Alignment.center,
            child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
          ),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Pal.mantle,
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
