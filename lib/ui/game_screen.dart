import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/board.dart';
import '../game/generator.dart';
import '../game/level.dart';
import '../services/stats.dart';
import '../theme/mocha.dart';
import 'board_widget.dart';
import 'confetti.dart';
import 'widgets.dart';

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

  void _newLevel() => _load();

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
    if (board == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                difficulty: widget.difficulty,
                size: null,
                time: '00:00',
                seed: null,
              ),
              const Expanded(child: _Loading()),
            ],
          ),
        ),
      );
    }
    final level = board.level;
    final won = board.won;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _TopBar(
                  difficulty: widget.difficulty,
                  size: level.size,
                  time: formatMs(_clock.elapsedMilliseconds),
                  seed: level.seed,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final side = math.min(c.maxWidth - 36, c.maxHeight - 110);
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: side,
                              height: side,
                              child: BoardWidget(
                                board: board,
                                haptics: widget.stats.haptics,
                                onWin: _onWin,
                              ),
                            ),
                            const SizedBox(height: 28),
                            _StatsRow(board: board),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      PillButton(
                        icon: Icons.refresh_rounded,
                        label: 'Restart',
                        onPressed: won ? null : _restart,
                      ),
                      PillButton(
                        icon: Icons.lightbulb_outline_rounded,
                        label: 'Hint',
                        onPressed: won ? null : _hint,
                      ),
                      PillButton(
                        icon: Icons.shuffle_rounded,
                        label: 'New',
                        onPressed: _newLevel,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_confettiKey > 0 && won)
              Positioned.fill(child: Confetti(key: ValueKey(_confettiKey))),
            if (_showWin)
              Positioned.fill(
                child: _WinOverlay(
                  time: formatMs(_clock.elapsedMilliseconds),
                  moves: board.moves,
                  colors: board.colorCount,
                  hints: board.hintsUsed,
                  newBest: _newBest,
                  onNext: _newLevel,
                  onHome: () => Navigator.of(context).pop(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final Difficulty difficulty;
  final int? size;
  final String time;
  final int? seed;
  const _TopBar({
    required this.difficulty,
    required this.size,
    required this.time,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Home',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  difficulty.label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  size == null ? 'Generating…' : '$size × $size   ·   #$seed',
                  style: const TextStyle(
                    color: Mocha.overlay1,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Mocha.mantle,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18, color: Mocha.subtext0),
                const SizedBox(width: 6),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Board board;
  const _StatsRow({required this.board});

  @override
  Widget build(BuildContext context) {
    final fill = (board.fillFraction * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          _Stat(
            label: 'flows',
            value: '${board.completedCount}/${board.colorCount}',
            color: Mocha.mauve,
          ),
          _Stat(label: 'filled', value: '$fill%', color: Mocha.blue),
          _Stat(label: 'moves', value: '${board.moves}', color: Mocha.peach),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Mocha.overlay1,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _WinOverlay extends StatelessWidget {
  final String time;
  final int moves;
  final int colors;
  final int hints;
  final bool newBest;
  final VoidCallback onNext;
  final VoidCallback onHome;

  const _WinOverlay({
    required this.time,
    required this.moves,
    required this.colors,
    required this.hints,
    required this.newBest,
    required this.onNext,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final perfect = moves == colors && hints == 0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Container(
        color: Mocha.crust.withValues(alpha: 0.62 * t.clamp(0, 1)),
        alignment: Alignment.center,
        child: Transform.scale(
          scale: 0.85 + 0.15 * t,
          child: Opacity(opacity: t.clamp(0, 1), child: child),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: MochaCard(
          padding: const EdgeInsets.fromLTRB(26, 28, 26, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final c in [Mocha.red, Mocha.yellow, Mocha.green, Mocha.blue, Mocha.mauve])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Dot(c, size: 12),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                perfect ? 'Perfect!' : 'Solved!',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (newBest)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Mocha.yellow.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'New best time',
                      style: TextStyle(
                        color: Mocha.yellow,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _WinStat('time', time),
                  _WinStat('moves', '$moves'),
                  _WinStat('hints', '$hints'),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  icon: Icons.arrow_forward_rounded,
                  label: 'Next puzzle',
                  color: Mocha.mauve,
                  foreground: Mocha.crust,
                  onPressed: onNext,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onHome,
                child: const Text(
                  'Home',
                  style: TextStyle(
                    color: Mocha.subtext0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WinStat extends StatelessWidget {
  final String label;
  final String value;
  const _WinStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Mocha.overlay1,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    ],
  );
}

/// Three breathing dots while a level is generated.
class _Loading extends StatefulWidget {
  const _Loading();

  @override
  State<_Loading> createState() => _LoadingState();
}

class _LoadingState extends State<_Loading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = [Mocha.mauve, Mocha.blue, Mocha.green];
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Transform.translate(
                  offset: Offset(
                    0,
                    -8 * math.sin((_c.value * 2 * math.pi) - i * 0.9).clamp(0, 1),
                  ),
                  child: Dot(colors[i], size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
