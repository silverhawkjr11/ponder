import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/board.dart';
import '../game/generator.dart';
import '../game/level.dart';
import '../services/stats.dart';
import '../theme/mocha.dart';
import 'board_widget.dart';
import 'confetti.dart';
import 'game_chrome.dart';

/// Flow mode: join every pair of dots.
class GameScreen extends StatefulWidget {
  final Difficulty difficulty;
  final Stats stats;
  final int? seed;

  const GameScreen({
    super.key,
    required this.difficulty,
    required this.stats,
    this.seed,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  Board? _board;
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
    final level = await LevelGenerator.generateAsync(widget.difficulty, seed: seed);
    if (!mounted || gen != _generation) return;
    final board = Board(level, requireFill: widget.stats.requireFill)
      ..addListener(_onBoard);
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
    final perfect = board.moves == board.colorCount;
    final best = await widget.stats.recordWin(
      GameMode.flow,
      widget.difficulty,
      ms: ms,
      perfect: perfect,
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
                  mode: GameMode.flow,
                  difficulty: widget.difficulty,
                  size: board?.level.size,
                  time: formatMs(_clock.elapsedMilliseconds),
                  seed: board?.level.seed,
                ),
                Expanded(
                  child: board == null
                      ? const GeneratingDots()
                      : BoardArea(
                          board: BoardWidget(
                            board: board,
                            haptics: widget.stats.haptics,
                            onWin: _onWin,
                          ),
                          stats: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Row(
                              children: [
                                StatTile(
                                  label: 'flows',
                                  value: '${board.completedCount}/${board.colorCount}',
                                  color: Mocha.mauve,
                                ),
                                StatTile(
                                  label: 'filled',
                                  value: '${(board.fillFraction * 100).round()}%',
                                  color: Mocha.blue,
                                ),
                                StatTile(
                                  label: 'moves',
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
                  title: board.moves == board.colorCount && board.hintsUsed == 0
                      ? 'Perfect!'
                      : 'Solved!',
                  stats: [
                    ('time', formatMs(_clock.elapsedMilliseconds)),
                    ('moves', '${board.moves}'),
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
