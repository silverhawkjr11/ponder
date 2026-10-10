import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/board.dart';
import '../game/level.dart';
import '../theme/palette.dart';

/// Paints the whole board: cell tints, grid, pipes, dots and effects.
class BoardPainter extends CustomPainter {
  final Board board;
  final Map<int, double> pulses; // color -> 0..1 completion pulse
  final double winGlow; // 0..1 after the board is solved

  BoardPainter({
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
    final r = Radius.circular(cell * 0.28);

    // Backplate.
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect.inflate(cell * 0.12), r),
      Paint()..color = Pal.mantle,
    );

    Offset center(Cell c) => Offset((c.c + 0.5) * cell, (c.r + 0.5) * cell);

    // Tinted cells under the pipes.
    final tint = Paint();
    for (var row = 0; row < n; row++) {
      for (var col = 0; col < n; col++) {
        final owner = board.ownerAt(Cell(row, col));
        if (owner == -1) continue;
        final base = Pal.flows[owner];
        final done = board.isComplete(owner);
        tint.color = base.withValues(alpha: done ? 0.22 : 0.14);
        final rect = Rect.fromLTWH(col * cell, row * cell, cell, cell)
            .deflate(cell * 0.06);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18)),
          tint,
        );
      }
    }

    // Faint grid dots at intersections, lighter than lines.
    final gridPaint = Paint()..color = Pal.surface1.withValues(alpha: 0.55);
    for (var i = 1; i < n; i++) {
      for (var j = 1; j < n; j++) {
        canvas.drawCircle(Offset(i * cell, j * cell), cell * 0.035, gridPaint);
      }
    }

    // Pipes.
    final stroke = cell * 0.34;
    for (var color = 0; color < board.colorCount; color++) {
      final path = board.pathOf(color);
      if (path.length < 2) continue;
      final c = Pal.flows[color];
      final active = board.active == color;
      final done = board.isComplete(color);
      final p = Path()..moveTo(center(path.first).dx, center(path.first).dy);
      for (final cellPt in path.skip(1)) {
        final o = center(cellPt);
        p.lineTo(o.dx, o.dy);
      }
      if (active || done || winGlow > 0) {
        final glowAlpha = active ? 0.35 : 0.18 + 0.25 * winGlow;
        canvas.drawPath(
          p,
          Paint()
            ..color = c.withValues(alpha: glowAlpha)
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
          ..color = active ? Color.lerp(c, Colors.white, 0.12)! : c
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Dots.
    final radius = cell * 0.31;
    for (var color = 0; color < board.colorCount; color++) {
      final (a, b) = board.level.endpoints[color];
      final c = Pal.flows[color];
      final done = board.isComplete(color);
      final pulse = pulses[color];
      for (final e in [a, b]) {
        final o = center(e);
        if (pulse != null) {
          final t = Curves.easeOut.transform(pulse);
          canvas.drawCircle(
            o,
            radius + cell * 0.45 * t,
            Paint()
              ..color = c.withValues(alpha: (1 - t) * 0.55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.08 * (1 - t) + 1,
          );
        }
        if (done || winGlow > 0) {
          canvas.drawCircle(
            o,
            radius * 1.25,
            Paint()
              ..color = c.withValues(alpha: 0.28 + 0.3 * winGlow)
              ..maskFilter = MaskFilter.blur(ui.BlurStyle.normal, cell * 0.16),
          );
        }
        canvas.drawCircle(o, radius, Paint()..color = c);
        // Soft highlight for a little depth.
        canvas.drawCircle(
          o.translate(-radius * 0.25, -radius * 0.28),
          radius * 0.42,
          Paint()..color = Colors.white.withValues(alpha: done ? 0.32 : 0.2),
        );
        if (board.active == color && board.pathOf(color).last == e) {
          // Ring the dot we're dragging from.
          canvas.drawCircle(
            o,
            radius + cell * 0.07,
            Paint()
              ..color = Pal.text.withValues(alpha: 0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = max(1.5, cell * 0.035),
          );
        }
      }
    }

    // Drag head.
    final active = board.active;
    if (active != null) {
      final path = board.pathOf(active);
      if (path.isNotEmpty && board.endpointAt(path.last) == -1) {
        canvas.drawCircle(
          center(path.last),
          stroke * 0.5,
          Paint()..color = Colors.white.withValues(alpha: 0.25),
        );
      }
    }
  }

  @override
  bool shouldRepaint(BoardPainter old) =>
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
