import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/level.dart';
import '../game/zip_board.dart';
import '../game/zip_generator.dart';
import '../services/progress.dart';
import '../services/stats.dart';
import '../theme/palette.dart';
import 'confetti.dart';
import 'game_chrome.dart';
import 'zip_board_widget.dart';

/// Zip mode: one path from 1 to N through every cell.
class ZipGameScreen extends StatefulWidget {
  final Difficulty difficulty;
  final Stats stats;
  final Map<String, dynamic>? resume;
  final int? seed;
  final bool daily;

  const ZipGameScreen({
    super.key,
    required this.difficulty,
    required this.stats,
    this.resume,
    this.seed,
    this.daily = false,
  });

  @override
  State<ZipGameScreen> createState() => _ZipGameScreenState();
}

class _ZipGameScreenState extends State<ZipGameScreen>
    with WidgetsBindingObserver {
  ZipBoard? _board;
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
    if (resume == null) widget.stats.clearSave(GameMode.zip);
    final fixedSeed = _first && resume == null ? widget.seed : null;
    _daily = _first && resume == null && widget.daily;
    _first = false;
    final level = await ZipGenerator.generateAsync(
      widget.difficulty,
      seed: (resume?['seed'] as int?) ?? fixedSeed,
    );
    if (!mounted || gen != _generation) return;
    final board = ZipBoard(level);
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
      widget.stats.clearSave(GameMode.zip);
      return;
    }
    widget.stats.saveGame(GameMode.zip, {
      'd': widget.difficulty.name,
      'seed': b.level.seed,
      'ms': _clock.ms,
      'progress': '${(b.fillFraction * 100).round()}% drawn',
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
    widget.stats.clearSave(GameMode.zip);
    final best = await widget.stats.recordWin(
      GameMode.zip,
      widget.difficulty,
      ms: _clock.ms,
      perfect: board.moves == 1,
      usedHints: board.hintsUsed > 0,
    );
    final award = await widget.stats.progress.record(
      ProgressEvent(mode: GameMode.zip, perfect: board.moves == 1, usedHints: board.hintsUsed > 0, difficulty: widget.difficulty, daily: _daily),
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
                  mode: GameMode.zip,
                  difficulty: widget.difficulty,
                  size: board?.level.size,
                  time: widget.stats.showTimer ? formatMs(_clock.ms) : null,
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
                                  color: Pal.mauve,
                                ),
                                StatTile(
                                  label: 'filled',
                                  value: '${(board.fillFraction * 100).round()}%',
                                  color: Pal.blue,
                                ),
                                StatTile(
                                  label: 'strokes',
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
                  title: board.moves == 1 && board.hintsUsed == 0
                      ? 'One stroke!'
                      : 'Solved!',
                  stats: [
                    ('time', formatMs(_clock.ms)),
                    ('strokes', '${board.moves}'),
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
