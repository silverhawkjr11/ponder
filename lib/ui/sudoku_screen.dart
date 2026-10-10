import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/level.dart';
import '../game/sudoku.dart';
import '../services/progress.dart';
import '../services/stats.dart';
import '../theme/palette.dart';
import 'confetti.dart';
import 'game_chrome.dart';

class SudokuScreen extends StatefulWidget {
  final Difficulty difficulty;
  final Stats stats;
  final Map<String, dynamic>? resume;
  final int? seed;
  final bool daily;
  const SudokuScreen({
    super.key,
    required this.difficulty,
    required this.stats,
    this.resume,
    this.seed,
    this.daily = false,
  });

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> with WidgetsBindingObserver {
  SudokuBoard? _board;
  int _generation = 0;
  final GameClock _clock = GameClock();
  Timer? _tick;
  bool _showWin = false;
  bool _newBest = false;
  bool _recorded = false;
  int _confettiKey = 0;
  Award? _award;
  bool _daily = false;
  bool _first = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && _board != null && !_board!.won) setState(() {});
    });
    _load(resume: widget.resume);
  }

  Future<void> _load({Map<String, dynamic>? resume}) async {
    final gen = ++_generation;
    final old = _board;
    setState(() => _board = null);
    old?.removeListener(_onBoard);
    old?.dispose();
    if (resume == null) widget.stats.clearSave(GameMode.sudoku);
    final fixedSeed = _first && resume == null ? widget.seed : null;
    _daily = _first && resume == null && widget.daily;
    _first = false;
    final level = await SudokuGenerator.generateAsync(
      widget.difficulty,
      seed: (resume?['seed'] as int?) ?? fixedSeed,
    );
    if (!mounted || gen != _generation) return;
    final board = SudokuBoard(level);
    if (resume != null) board.restore(resume);
    board.addListener(_onBoard);
    setState(() {
      _board = board;
      _showWin = false;
      _newBest = false;
      _recorded = false;
      _award = null;
      _clock.reset(from: (resume?['ms'] as int?) ?? 0);
    });
  }

  void _persist() {
    final b = _board;
    if (b == null) return;
    if (b.won) {
      widget.stats.clearSave(GameMode.sudoku);
      return;
    }
    widget.stats.saveGame(GameMode.sudoku, {
      'd': widget.difficulty.name,
      'seed': b.level.seed,
      'ms': _clock.ms,
      'progress': '${b.filled}/81 filled',
      ...b.toJson(),
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _persist();
    _board?.removeListener(_onBoard);
    _board?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_board != null && !_board!.won) _clock.start();
    } else {
      _clock.stop();
      _persist();
    }
  }

  void _onBoard() {
    if (!mounted) return;
    final b = _board!;
    if (b.won && !_recorded) {
      _recorded = true;
      _onWin(b);
    }
    setState(() {});
    _persist();
  }

  Future<void> _onWin(SudokuBoard b) async {
    _clock.stop();
    widget.stats.clearSave(GameMode.sudoku);
    if (widget.stats.haptics) HapticFeedback.heavyImpact();
    final best = await widget.stats.recordWin(
      GameMode.sudoku,
      widget.difficulty,
      ms: _clock.ms,
      perfect: b.mistakes == 0,
      usedHints: b.hintsUsed > 0,
    );
    final award = await widget.stats.progress.record(
      ProgressEvent(
        mode: GameMode.sudoku,
        difficulty: widget.difficulty,
        perfect: b.mistakes == 0,
        usedHints: b.hintsUsed > 0,
        daily: _daily,
      ),
      chessRating: widget.stats.chessRating,
    );
    if (!mounted) return;
    setState(() {
      _newBest = best;
      _award = award;
      _confettiKey++;
    });
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _showWin = true);
  }

  void _tap(VoidCallback f) {
    if (widget.stats.haptics) HapticFeedback.selectionClick();
    f();
  }

  @override
  Widget build(BuildContext context) {
    final b = _board;
    final won = b?.won ?? false;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                GameTopBar(
                  mode: GameMode.sudoku,
                  difficulty: widget.difficulty,
                  size: null,
                  subtitle: b == null ? 'Generating…' : '${b.level.clueCount} clues   ·   #${b.level.seed}',
                  time: widget.stats.showTimer ? formatMs(_clock.ms) : null,
                  seed: null,
                ),
                Expanded(
                  child: b == null
                      ? const GeneratingDots()
                      : LayoutBuilder(
                          builder: (context, c) {
                            final side = (c.maxWidth - 20).clamp(0.0, c.maxHeight - 230);
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: side,
                                  height: side,
                                  child: _SudokuGrid(board: b, showMistakes: widget.stats.showMistakes),
                                ),
                                const SizedBox(height: 18),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  child: Row(
                                    children: [
                                      StatTile(
                                        label: 'mistakes',
                                        value: widget.stats.showMistakes ? '${b.mistakes}' : '·',
                                        color: !widget.stats.showMistakes || b.mistakes == 0 ? Pal.green : Pal.red,
                                      ),
                                      StatTile(
                                        label: 'filled',
                                        value: '${b.filled}/81',
                                        color: Pal.blue,
                                      ),
                                      StatTile(
                                        label: 'hints',
                                        value: '${b.hintsUsed}',
                                        color: Pal.peach,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _Pad(board: b, onTap: _tap, onNew: _load),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
            if (_confettiKey > 0 && won)
              Positioned.fill(child: Confetti(key: ValueKey(_confettiKey))),
            if (_showWin && b != null)
              Positioned.fill(
                child: WinOverlay(
                  title: b.mistakes == 0 && b.hintsUsed == 0 ? 'Flawless!' : 'Solved!',
                  stats: [
                    ('time', formatMs(_clock.ms)),
                    ('mistakes', '${b.mistakes}'),
                    ('hints', '${b.hintsUsed}'),
                  ],
                  newBest: _newBest,
                  award: _award,
                  onNext: _load,
                  onHome: () => Navigator.of(context).pop(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SudokuGrid extends StatelessWidget {
  final SudokuBoard board;
  final bool showMistakes;
  const _SudokuGrid({required this.board, required this.showMistakes});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cell = c.biggest.shortestSide / 9;
        return GestureDetector(
          onTapDown: (d) {
            final col = (d.localPosition.dx / cell).floor().clamp(0, 8);
            final row = (d.localPosition.dy / cell).floor().clamp(0, 8);
            board.select(row * 9 + col);
          },
          child: CustomPaint(
            size: Size.square(cell * 9),
            painter: _SudokuPainter(board, showMistakes),
          ),
        );
      },
    );
  }
}

class _SudokuPainter extends CustomPainter {
  final SudokuBoard board;
  final bool showMistakes;
  _SudokuPainter(this.board, this.showMistakes) : super(repaint: board);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cell * 0.3));
    canvas.drawRRect(rrect.inflate(cell * 0.1), Paint()..color = Pal.mantle);
    canvas.save();
    canvas.clipRRect(rrect);

    final sel = board.selected;
    final selValue = sel != null ? board.values[sel] : 0;
    final paint = Paint();
    for (var i = 0; i < 81; i++) {
      final r = i ~/ 9, c = i % 9;
      final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
      Color? bg;
      if (sel != null) {
        if (i == sel) {
          bg = Pal.mauve.withValues(alpha: 0.35);
        } else if (selValue != 0 && board.values[i] == selValue) {
          bg = Pal.blue.withValues(alpha: 0.28);
        } else if (SudokuBoard.peers(sel, i)) {
          bg = Pal.surface0.withValues(alpha: 0.6);
        }
      }
      if (bg != null) canvas.drawRect(rect, paint..color = bg);
    }

    // Thin and thick lines.
    for (var k = 0; k <= 9; k++) {
      final thick = k % 3 == 0;
      final p = Paint()
        ..color = thick ? Pal.subtext0 : Pal.surface1
        ..strokeWidth = thick ? 2.5 : 1;
      canvas.drawLine(Offset(k * cell, 0), Offset(k * cell, size.height), p);
      canvas.drawLine(Offset(0, k * cell), Offset(size.width, k * cell), p);
    }

    for (var i = 0; i < 81; i++) {
      final r = i ~/ 9, c = i % 9;
      final center = Offset((c + 0.5) * cell, (r + 0.5) * cell);
      final v = board.values[i];
      if (v != 0) {
        final given = board.isGiven(i);
        final wrong = showMistakes && board.isWrong(i);
        final tp = TextPainter(
          text: TextSpan(
            text: '$v',
            style: TextStyle(
              fontSize: cell * 0.55,
              fontWeight: given ? FontWeight.w800 : FontWeight.w700,
              color: wrong ? Pal.red : given ? Pal.text : Pal.lavender,
              fontFamily: 'Nunito',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      } else if (board.notes[i].isNotEmpty) {
        for (final n in board.notes[i]) {
          final nr = (n - 1) ~/ 3, nc = (n - 1) % 3;
          final tp = TextPainter(
            text: TextSpan(
              text: '$n',
              style: TextStyle(
                fontSize: cell * 0.24,
                fontWeight: FontWeight.w700,
                color: selValue == n ? Pal.blue : Pal.overlay1,
                fontFamily: 'Nunito',
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final o = Offset(c * cell + (nc + 0.5) * cell / 3, r * cell + (nr + 0.5) * cell / 3);
          tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SudokuPainter old) => true;
}

class _Pad extends StatelessWidget {
  final SudokuBoard board;
  final void Function(VoidCallback) onTap;
  final VoidCallback onNew;
  const _Pad({required this.board, required this.onTap, required this.onNew});

  @override
  Widget build(BuildContext context) {
    final won = board.won;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        children: [
          Row(
            children: [
              for (var d = 1; d <= 9; d++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: _Key(
                      label: '$d',
                      sub: board.remainingOf(d) > 0 ? '${board.remainingOf(d)}' : '',
                      dim: board.remainingOf(d) <= 0,
                      onTap: won ? null : () => onTap(() => board.enter(d)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Tool(
                icon: Icons.undo_rounded,
                label: 'Undo',
                onTap: won || !board.canUndo ? null : () => onTap(board.undo),
              ),
              _Tool(
                icon: Icons.backspace_outlined,
                label: 'Erase',
                onTap: won ? null : () => onTap(board.erase),
              ),
              _Tool(
                icon: Icons.edit_outlined,
                label: 'Notes',
                active: board.pencil,
                onTap: won ? null : () => onTap(board.togglePencil),
              ),
              _Tool(
                icon: Icons.lightbulb_outline_rounded,
                label: 'Hint',
                onTap: won ? null : () => onTap(() => board.hint()),
              ),
              _Tool(
                icon: Icons.shuffle_rounded,
                label: 'New',
                onTap: onNew,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final String label;
  final String sub;
  final bool dim;
  final VoidCallback? onTap;
  const _Key({required this.label, required this.sub, required this.dim, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Pal.surface0,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: dim ? 0.35 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Pal.lavender,
                  ),
                ),
                Text(
                  sub.isEmpty ? ' ' : sub,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Pal.overlay1,
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

class _Tool extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _Tool({required this.icon, required this.label, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? Pal.mauve : Pal.subtext1;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Pal.mauve.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
