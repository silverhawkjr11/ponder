import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/board.dart';
import '../game/generator.dart';
import '../game/level.dart';
import '../services/progress.dart';
import '../services/stats.dart';
import '../theme/palette.dart';
import 'board_widget.dart';
import 'confetti.dart';
import 'game_chrome.dart';

/// Flow mode: join every pair of dots.
class GameScreen extends StatefulWidget {
  final Difficulty difficulty;
  final Stats stats;
  final Map<String, dynamic>? resume;
  final int? seed;
  final bool daily;

  const GameScreen({
    super.key,
    required this.difficulty,
    required this.stats,
    this.resume,
    this.seed,
    this.daily = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  Board? _board;
  int _generation = 0;
  final GameClock _clock = GameClock();
  Timer? _tick;
  bool _showWin = false;
  bool _newBest = false;
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
    if (resume == null) widget.stats.clearSave(GameMode.flow);
    final fixedSeed = _first && resume == null ? widget.seed : null;
    _daily = _first && resume == null && widget.daily;
    _first = false;
    final level = await LevelGenerator.generateAsync(
      widget.difficulty,
      seed: (resume?['seed'] as int?) ?? fixedSeed,
    );
    if (!mounted || gen != _generation) return;
    final board = Board(level, requireFill: widget.stats.requireFill);
    if (resume != null) board.restore(resume);
    board.addListener(_onBoard);
    setState(() {
      _board = board;
      _showWin = false;
      _newBest = false;
      _award = null;
      _clock.reset(from: (resume?['ms'] as int?) ?? 0);
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

  void _persist() {
    final b = _board;
    if (b == null) return;
    if (b.won) {
      widget.stats.clearSave(GameMode.flow);
      return;
    }
    widget.stats.saveGame(GameMode.flow, {
      'd': widget.difficulty.name,
      'seed': b.level.seed,
      'ms': _clock.ms,
      'progress': '${b.completedCount}/${b.colorCount} flows',
      ...b.toJson(),
    });
  }

  void _onBoard() {
    if (!mounted) return;
    setState(() {});
    _persist();
  }

  Future<void> _onWin() async {
    final board = _board!;
    _clock.stop();
    widget.stats.clearSave(GameMode.flow);
    final perfect = board.moves == board.colorCount;
    final best = await widget.stats.recordWin(
      GameMode.flow,
      widget.difficulty,
      ms: _clock.ms,
      perfect: perfect,
      usedHints: board.hintsUsed > 0,
    );
    final award = await widget.stats.progress.record(
      ProgressEvent(mode: GameMode.flow, perfect: perfect, usedHints: board.hintsUsed > 0, difficulty: widget.difficulty, daily: _daily),
      chessRating: widget.stats.chessRating,
    );
    if (!mounted) return;
    setState(() {
      _newBest = best;
      _award = award;
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
      _clock.reset();
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
                  time: widget.stats.showTimer ? formatMs(_clock.ms) : null,
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
                                  color: Pal.mauve,
                                ),
                                StatTile(
                                  label: 'filled',
                                  value: '${(board.fillFraction * 100).round()}%',
                                  color: Pal.blue,
                                ),
                                StatTile(
                                  label: 'moves',
                                  value: '${board.moves}',
                                  color: Pal.peach,
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 14),
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
                    ('time', formatMs(_clock.ms)),
                    ('moves', '${board.moves}'),
                    ('hints', '${board.hintsUsed}'),
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
