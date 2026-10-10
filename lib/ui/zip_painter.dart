import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/level.dart';
import '../game/zip_board.dart';
import '../theme/palette.dart';

class ZipPainter extends CustomPainter {
  final ZipBoard board;
  final Map<int, double> pulses; // number -> 0..1
  final double winGlow;

  static Color pathColor = Pal.mauve;

  ZipPainter({
    required this.board,
    required this.pulses,
    required this.winGlow,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    final cell = size.shortestSide / n;
    final boardRect = Offset.zero & Size(cell * n, cell * n);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        boardRect.inflate(cell * 0.12),
        Radius.circular(cell * 0.28),
      ),
      Paint()..color = Pal.mantle,
    );

    Offset center(Cell c) => Offset((c.c + 0.5) * cell, (c.r + 0.5) * cell);

    // Visited tint.
    final tint = Paint()
      ..color = pathColor.withValues(alpha: board.won ? 0.2 : 0.13);
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (!board.visited(Cell(r, c))) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(c * cell, r * cell, cell, cell).deflate(cell * 0.06),
            Radius.circular(cell * 0.18),
          ),
          tint,
        );
      }
    }

    // Grid dots.
    final gridPaint = Paint()..color = Pal.surface1.withValues(alpha: 0.55);
    for (var i = 1; i < n; i++) {
      for (var j = 1; j < n; j++) {
        canvas.drawCircle(Offset(i * cell, j * cell), cell * 0.035, gridPaint);
      }
    }

    // Path.
    final path = board.path;
    final stroke = cell * 0.3;
    if (path.length >= 2) {
      final p = Path()..moveTo(center(path.first).dx, center(path.first).dy);
      for (final c in path.skip(1)) {
        final o = center(c);
        p.lineTo(o.dx, o.dy);
      }
      if (board.active || winGlow > 0) {
        canvas.drawPath(
          p,
          Paint()
            ..color = pathColor.withValues(alpha: 0.2 + 0.3 * winGlow)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke * 1.9
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter = MaskFilter.blur(ui.BlurStyle.normal, cell * 0.18),
        );
      }
      canvas.drawPath(
        p,
        Paint()
          ..color = pathColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Walls.
    final wallPaint = Paint()
      ..color = Pal.text.withValues(alpha: 0.9)
      ..strokeWidth = max(3, cell * 0.09)
      ..strokeCap = StrokeCap.round;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final a = Cell(r, c);
        if (c < n - 1 && board.level.hasWall(a, Cell(r, c + 1))) {
          final x = (c + 1) * cell;
          canvas.drawLine(
            Offset(x, r * cell + cell * 0.08),
            Offset(x, (r + 1) * cell - cell * 0.08),
            wallPaint,
          );
        }
        if (r < n - 1 && board.level.hasWall(a, Cell(r + 1, c))) {
          final y = (r + 1) * cell;
          canvas.drawLine(
            Offset(c * cell + cell * 0.08, y),
            Offset((c + 1) * cell - cell * 0.08, y),
            wallPaint,
          );
        }
      }
    }

    // Numbers.
    final radius = cell * 0.31;
    final next = board.nextNumber;
    for (var i = 0; i < board.numberCount; i++) {
      final num = i + 1;
      final c = board.level.waypoints[i];
      final o = center(c);
      final done = board.visited(c);
      final pulse = pulses[num];
      if (pulse != null) {
        final t = Curves.easeOut.transform(pulse);
        canvas.drawCircle(
          o,
          radius + cell * 0.45 * t,
          Paint()
            ..color = pathColor.withValues(alpha: (1 - t) * 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.08 * (1 - t) + 1,
        );
      }
      if (done || winGlow > 0) {
        canvas.drawCircle(
          o,
          radius * 1.2,
          Paint()
            ..color = pathColor.withValues(alpha: 0.25 + 0.3 * winGlow)
            ..maskFilter = MaskFilter.blur(ui.BlurStyle.normal, cell * 0.16),
        );
      }
      canvas.drawCircle(
        o,
        radius,
        Paint()..color = done ? pathColor : Pal.surface1,
      );
      if (!done && num == next && !board.won) {
        canvas.drawCircle(
          o,
          radius + cell * 0.06,
          Paint()
            ..color = pathColor.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.5, cell * 0.04),
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: '$num',
          style: TextStyle(
            color: done ? Pal.crust : Pal.text,
            fontSize: cell * (num >= 10 ? 0.3 : 0.36),
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }

    // Head marker on plain cells.
    if (board.numberAt(board.head) == 0) {
      canvas.drawCircle(
        center(board.head),
        stroke * 0.5,
        Paint()..color = Colors.white.withValues(alpha: board.active ? 0.3 : 0.18),
      );
    }
  }

  @override
  bool shouldRepaint(ZipPainter old) =>
      old.board != board ||
      old.winGlow != winGlow ||
      !_mapEq(old.pulses, pulses);

  static bool _mapEq(Map<int, double> a, Map<int, double> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
