import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/board.dart';
import '../game/level.dart';
import 'board_painter.dart';

/// Square, touch-driven board. Uses raw pointer events so a pipe starts
/// growing the instant the finger lands, with no gesture slop delay.
class BoardWidget extends StatefulWidget {
  final Board board;
  final bool haptics;
  final VoidCallback? onWin;

  const BoardWidget({
    super.key,
    required this.board,
    required this.haptics,
    this.onWin,
  });

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final Map<int, Duration> _pulseStart = {};
  final Map<int, double> _pulses = {};
  Duration? _winStart;
  double _winGlow = 0;
  Duration _now = Duration.zero;
  bool _wonReported = false;
  int? _pointer;

  static const _pulseLen = Duration(milliseconds: 550);
  static const _winLen = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.board.addListener(_onBoardChanged);
  }

  @override
  void didUpdateWidget(covariant BoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.board != widget.board) {
      oldWidget.board.removeListener(_onBoardChanged);
      widget.board.addListener(_onBoardChanged);
      _pulseStart.clear();
      _pulses.clear();
      _winStart = null;
      _winGlow = 0;
      _wonReported = false;
      _pointer = null;
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    widget.board.removeListener(_onBoardChanged);
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    _now = elapsed;
    var busy = false;
    final next = <int, double>{};
    _pulseStart.forEach((color, start) {
      final t = (elapsed - start).inMicroseconds / _pulseLen.inMicroseconds;
      if (t < 1) {
        next[color] = t.clamp(0, 1);
        busy = true;
      }
    });
    _pulseStart.removeWhere((k, _) => !next.containsKey(k));
    if (_winStart != null) {
      final t = (elapsed - _winStart!).inMicroseconds / _winLen.inMicroseconds;
      _winGlow = Curves.easeInOut.transform(t.clamp(0, 1).toDouble());
      if (t < 1) busy = true;
    }
    setState(() => _pulses
      ..clear()
      ..addAll(next));
    if (!busy) _ticker.stop();
  }

  void _pulse(int color) {
    _pulseStart[color] = _ticker.isActive ? _now : Duration.zero;
    if (!_ticker.isActive) {
      _now = Duration.zero;
      _ticker.start();
    }
  }

  void _handleComplete(int color) {
    if (widget.haptics) HapticFeedback.lightImpact();
    _pulse(color);
  }

  void _onBoardChanged() {
    final board = widget.board;
    if (!board.won) {
      _wonReported = false;
      if (_winStart != null) {
        _winStart = null;
        _winGlow = 0;
        if (mounted) setState(() {});
      }
      return;
    }
    if (_wonReported) return;
    _wonReported = true;
    if (widget.haptics) HapticFeedback.heavyImpact();
    _winStart = _ticker.isActive ? _now : Duration.zero;
    if (!_ticker.isActive) {
      _now = Duration.zero;
      _ticker.start();
    }
    widget.onWin?.call();
  }

  Cell _cellAt(Offset local, double cellSize) =>
      Cell((local.dy / cellSize).floor(), (local.dx / cellSize).floor());

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final cellSize = side / widget.board.size;
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) {
                if (_pointer != null) return;
                final cell = _cellAt(e.localPosition, cellSize);
                if (widget.board.beginDrag(cell)) {
                  _pointer = e.pointer;
                  if (widget.haptics) HapticFeedback.selectionClick();
                }
              },
              onPointerMove: (e) {
                if (e.pointer != _pointer) return;
                final cell = _cellAt(e.localPosition, cellSize);
                widget.board.dragTo(cell, onComplete: _handleComplete);
              },
              onPointerUp: (e) {
                if (e.pointer != _pointer) return;
                _pointer = null;
                widget.board.endDrag();
              },
              onPointerCancel: (e) {
                if (e.pointer != _pointer) return;
                _pointer = null;
                widget.board.endDrag();
              },
              child: CustomPaint(
                painter: BoardPainter(
                  board: widget.board,
                  pulses: Map.of(_pulses),
                  winGlow: _winGlow,
                  repaint: widget.board,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
