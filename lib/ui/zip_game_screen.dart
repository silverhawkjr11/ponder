import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/level.dart';
import '../game/zip_board.dart';
import '../game/zip_generator.dart';
import '../services/stats.dart';
import '../theme/mocha.dart';
import 'confetti.dart';
import 'game_chrome.dart';
import 'zip_board_widget.dart';

/// Zip mode: one path from 1 to N through every cell.
class ZipGameScreen extends StatefulWidget {
  final Difficulty difficulty;
  final Stats stats;
  final int? seed;

  const ZipGameScreen({
    super.key,
    required this.difficulty,
    required this.stats,
    this.seed,
  });

  @override
  State<ZipGameScreen> createState() => _ZipGameScreenState();
}

class _ZipGameScreenState extends State<ZipGameScreen>
    with WidgetsBindingObserver {
  ZipBoard? _board;
  int _generation = 0;
  final Stopwatch _clock = Stopwatch();
  Timer? _tick;
  bool _showWin = false;
  bool _newBest = false;
  int _confettiKey = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && _board != null && !_board!.won) setState(() {});
    });
    _load(seed: widget.seed);
  }

  Future<void> _load({int? seed}) async {
    final gen = ++_generation;
    final old = _board;
    setState(() => _board = null);
    old?.removeListener(_onBoard);
    old?.dispose();
    final level = await ZipGenerator.generateAsync(widget.difficulty, seed: seed);
    if (!mounted || gen != _generation) return;
    final board = ZipBoard(level)..addListener(_onBoard);
    setState(() {
      _board = board;
      _showWin = false;
      _newBest = false;
      _clock
        ..reset()
        ..start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
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
    }
  }

  void _onBoard() {
    if (mounted) setState(() {});
  }

  Future<void> _onWin() async {
    final board = _board!;
    _clock.stop();
    final ms = _clock.elapsedMilliseconds;
    final best = await widget.stats.recordWin(
      GameMode.zip,
      widget.difficulty,
      ms: ms,
      perfect: board.moves == 1,
      usedHints: board.hintsUsed > 0,
    );
    if (!mounted) return;
    setState(() {
      _newBest = best;
      _confettiKey++;
    });
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _showWin = true);
  }

  void _restart() {
    _board?.restart();
    setState(() {
      _showWin = false;
      _clock
        ..reset()
        ..start();
    });
  }

  void _hint() {
    if (_board?.hint() != true) return;
    if (widget.stats.haptics) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    final won = board?.won ?? false;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                GameTopBar(
                  mode: GameMode.zip,
                  difficulty: widget.difficulty,
                  size: board?.level.size,
                  time: formatMs(_clock.elapsedMilliseconds),
                  seed: board?.level.seed,
                ),
                Expanded(
                  child: board == null
                      ? const GeneratingDots()
                      : BoardArea(
                          board: ZipBoardWidget(
                            board: board,
                            haptics: widget.stats.haptics,
                            onWin: _onWin,
                          ),
                          stats: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Row(
                              children: [
                                StatTile(
                                  label: 'numbers',
                                  value: '${board.reached}/${board.numberCount}',
                                  color: Mocha.mauve,
                                ),
                                StatTile(
                                  label: 'filled',
                                  value: '${(board.fillFraction * 100).round()}%',
                                  color: Mocha.blue,
                                ),
                                StatTile(
                                  label: 'strokes',
                                  value: '${board.moves}',
                                  color: Mocha.peach,
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 18),
                GameButtons(
                  onRestart: board == null || won ? null : _restart,
                  onHint: board == null || won ? null : _hint,
                  onNew: board == null ? null : _load,
                ),
              ],
            ),
            if (_confettiKey > 0 && won)
              Positioned.fill(child: Confetti(key: ValueKey(_confettiKey))),
            if (_showWin && board != null)
              Positioned.fill(
                child: WinOverlay(
                  title: board.moves == 1 && board.hintsUsed == 0
                      ? 'One stroke!'
                      : 'Solved!',
                  stats: [
                    ('time', formatMs(_clock.elapsedMilliseconds)),
                    ('strokes', '${board.moves}'),
                    ('hints', '${board.hintsUsed}'),
                  ],
                  newBest: _newBest,
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
