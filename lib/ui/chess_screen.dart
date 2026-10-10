import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/chess_puzzle.dart';
import '../game/chess_session.dart';
import '../game/level.dart';
import '../services/stats.dart';
import '../theme/mocha.dart';
import 'chess_board_widget.dart';
import 'confetti.dart';
import 'game_chrome.dart';
import 'widgets.dart';

class ChessScreen extends StatefulWidget {
  final Difficulty difficulty;
  final Stats stats;
  const ChessScreen({super.key, required this.difficulty, required this.stats});

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  ChessPuzzles? _puzzles;
  ChessSession? _session;
  final Stopwatch _clock = Stopwatch();
  Timer? _tick;
  bool _showWin = false;
  bool _recorded = false;
  int _delta = 0;
  int _confettiKey = 0;
  Timer? _wrongTimer;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && _session != null && !_session!.solved) setState(() {});
    });
    _load();
  }

  Future<void> _load() async {
    final old = _session;
    setState(() => _session = null);
    old?.removeListener(_onSession);
    old?.dispose();
    _puzzles ??= await ChessPuzzles.load();
    if (!mounted) return;
    final puzzle = _puzzles!.pick(
      widget.difficulty,
      avoid: widget.stats.chessSeen,
    );
    final session = ChessSession(puzzle)..addListener(_onSession);
    setState(() {
      _session = session;
      _showWin = false;
      _recorded = false;
      _delta = 0;
      _clock
        ..reset()
        ..start();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _wrongTimer?.cancel();
    _session?.removeListener(_onSession);
    _session?.dispose();
    super.dispose();
  }

  void _onSession() {
    final s = _session;
    if (s == null || !mounted) return;
    if (s.wrongMove != null) {
      if (widget.stats.haptics) HapticFeedback.vibrate();
      _wrongTimer?.cancel();
      _wrongTimer = Timer(const Duration(milliseconds: 700), () {
        s.wrongMove = null;
        if (mounted) setState(() {});
      });
    } else if (s.lastMove != null && widget.stats.haptics) {
      HapticFeedback.selectionClick();
    }
    if (s.solved && !_recorded) {
      _recorded = true;
      _onSolved(s);
    }
    setState(() {});
  }

  Future<void> _onSolved(ChessSession s) async {
    _clock.stop();
    if (widget.stats.haptics) HapticFeedback.heavyImpact();
    final delta = await widget.stats.recordChess(
      widget.difficulty,
      puzzleRating: s.puzzle.rating,
      clean: s.clean,
      id: s.puzzle.id,
    );
    if (!mounted) return;
    setState(() {
      _delta = delta;
      if (s.clean) _confettiKey++;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _showWin = true);
  }

  String _status(ChessSession s) {
    final side = s.userSide == Side.white ? 'White' : 'Black';
    return switch (s.state) {
      PuzzleState.intro => 'Watch…',
      PuzzleState.thinking =>
        s.wrongMove != null
            ? 'Not that one, try again'
            : s.pos.isCheck
            ? '$side to move — check!'
            : '$side to move',
      PuzzleState.replying => '…',
      PuzzleState.solved => 'Solved',
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final stats = widget.stats;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                GameTopBar(
                  mode: GameMode.chess,
                  difficulty: widget.difficulty,
                  size: null,
                  subtitle: s == null
                      ? 'Loading…'
                      : widget.difficulty.ratingLabel,
                  time: formatMs(_clock.elapsedMilliseconds),
                  seed: null,
                ),
                Expanded(
                  child: s == null
                      ? const GeneratingDots()
                      : BoardArea(
                          board: ChessBoardWidget(session: s),
                          stats: Column(
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                transitionBuilder: (child, a) => FadeTransition(
                                  opacity: a,
                                  child: SlideTransition(
                                    position: Tween(
                                      begin: const Offset(0, 0.3),
                                      end: Offset.zero,
                                    ).animate(a),
                                    child: child,
                                  ),
                                ),
                                child: Row(
                                  key: ValueKey(_status(s)),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Dot(
                                      s.wrongMove != null
                                          ? Mocha.red
                                          : s.userSide == Side.white
                                          ? Mocha.text
                                          : Mocha.surface2,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _status(s),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: s.wrongMove != null
                                            ? Mocha.red
                                            : Mocha.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                child: Row(
                                  children: [
                                    StatTile(
                                      label: 'rating',
                                      value: '${stats.chessRating}',
                                      color: Mocha.mauve,
                                    ),
                                    StatTile(
                                      label: 'puzzle',
                                      value: s.solved
                                          ? '${s.puzzle.rating}'
                                          : '?',
                                      color: Mocha.blue,
                                    ),
                                    StatTile(
                                      label: 'streak',
                                      value: '${stats.chessStreak}',
                                      color: Mocha.peach,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 18),
                GameButtons(
                  onRestart: s == null || s.solved ? null : () => s.retry(),
                  onHint: s == null || !s.userTurn ? null : () => s.hint(),
                  onNew: s == null ? null : _load,
                ),
              ],
            ),
            if (_confettiKey > 0 && (s?.solved ?? false))
              Positioned.fill(child: Confetti(key: ValueKey(_confettiKey))),
            if (_showWin && s != null)
              Positioned.fill(
                child: WinOverlay(
                  title: s.clean ? 'Perfect!' : 'Solved',
                  subtitle: s.puzzle.themes
                      .map(ChessPuzzle.themeLabel)
                      .join(' · '),
                  stats: [
                    ('rating', _delta >= 0 ? '+$_delta' : '$_delta'),
                    ('puzzle', '${s.puzzle.rating}'),
                    ('time', formatMs(_clock.elapsedMilliseconds)),
                  ],
                  newBest: false,
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
