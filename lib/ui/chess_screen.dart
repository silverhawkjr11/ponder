import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/chess_puzzle.dart';
import '../game/chess_session.dart';
import '../game/level.dart';
import '../services/progress.dart';
import '../services/stats.dart';
import '../theme/palette.dart';
import 'chess_board_widget.dart';
import 'confetti.dart';
import 'game_chrome.dart';
import 'widgets.dart';

class ChessScreen extends StatefulWidget {
  final Difficulty difficulty;
  final Stats stats;
  final Map<String, dynamic>? resume;
  final int? puzzleSeed;
  final bool daily;
  const ChessScreen({
    super.key,
    required this.difficulty,
    required this.stats,
    this.resume,
    this.puzzleSeed,
    this.daily = false,
  });

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> with WidgetsBindingObserver {
  ChessPuzzles? _puzzles;
  ChessSession? _session;
  final GameClock _clock = GameClock();
  Timer? _tick;
  bool _showWin = false;
  bool _recorded = false;
  int _delta = 0;
  int _confettiKey = 0;
  Timer? _wrongTimer;
  Award? _award;
  bool _daily = false;
  bool _first = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && _session != null && !_session!.solved) setState(() {});
    });
    _load(resume: widget.resume);
  }

  Future<void> _load({Map<String, dynamic>? resume}) async {
    final old = _session;
    setState(() => _session = null);
    old?.removeListener(_onSession);
    old?.dispose();
    if (resume == null) widget.stats.clearSave(GameMode.chess);
    _puzzles ??= await ChessPuzzles.load();
    if (!mounted) return;
    ChessPuzzle? puzzle;
    if (resume != null) puzzle = _puzzles!.byId(resume['id'] as String);
    if (puzzle == null && _first && widget.puzzleSeed != null) {
      puzzle = _puzzles!.pickDeterministic(widget.difficulty, widget.puzzleSeed!);
    }
    _daily = _first && resume == null && widget.daily;
    _first = false;
    puzzle ??= _puzzles!.pick(widget.difficulty, avoid: widget.stats.chessSeen);
    final session = ChessSession(
      puzzle,
      autoQueen: widget.stats.autoQueen,
      resumeStep: (resume?['step'] as int?) ?? 0,
      wrong: (resume?['wrong'] as int?) ?? 0,
      hints: (resume?['hints'] as int?) ?? 0,
    )..addListener(_onSession);
    setState(() {
      _session = session;
      _showWin = false;
      _recorded = false;
      _delta = 0;
      _award = null;
      _clock.reset(from: (resume?['ms'] as int?) ?? 0);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _wrongTimer?.cancel();
    _persist();
    _session?.removeListener(_onSession);
    _session?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_session != null && !_session!.solved) _clock.start();
    } else {
      _clock.stop();
      _persist();
    }
  }

  void _persist() {
    final s = _session;
    if (s == null) return;
    if (s.solved) {
      widget.stats.clearSave(GameMode.chess);
      return;
    }
    final total = (s.line.length / 2).ceil();
    final done = s.step ~/ 2;
    widget.stats.saveGame(GameMode.chess, {
      'd': widget.difficulty.name,
      'ms': _clock.ms,
      'progress': 'move ${done + 1} of $total',
      ...s.toJson(),
    });
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
    _persist();
  }

  Future<void> _onSolved(ChessSession s) async {
    _clock.stop();
    widget.stats.clearSave(GameMode.chess);
    if (widget.stats.haptics) HapticFeedback.heavyImpact();
    final delta = await widget.stats.recordChess(
      widget.difficulty,
      puzzleRating: s.puzzle.rating,
      clean: s.clean,
      id: s.puzzle.id,
    );
    final award = await widget.stats.progress.record(
      ProgressEvent(
        mode: GameMode.chess,
        difficulty: widget.difficulty,
        perfect: s.clean,
        usedHints: s.hintsUsed > 0,
        puzzleRating: s.puzzle.rating,
        daily: _daily,
      ),
      chessRating: widget.stats.chessRating,
    );
    if (!mounted) return;
    setState(() {
      _delta = delta;
      _award = award;
      if (s.clean) _confettiKey++;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _showWin = true);
  }

  String _status(ChessSession s) {
    final side = s.userSide == Side.white ? 'White' : 'Black';
    return switch (s.state) {
      PuzzleState.intro => 'Watch…',
      PuzzleState.thinking => s.wrongMove != null
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
                  subtitle: s == null ? 'Loading…' : widget.difficulty.ratingLabel,
                  time: stats.showTimer ? formatMs(_clock.ms) : null,
                  seed: null,
                ),
                Expanded(
                  child: s == null
                      ? const GeneratingDots()
                      : BoardArea(
                          reserve: 118,
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
                                          ? Pal.red
                                          : s.userSide == Side.white
                                              ? Pal.text
                                              : Pal.surface2,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _status(s),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: s.wrongMove != null ? Pal.red : Pal.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                child: Row(
                                  children: [
                                    StatTile(
                                      label: 'rating',
                                      value: '${stats.chessRating}',
                                      color: Pal.mauve,
                                    ),
                                    StatTile(
                                      label: 'puzzle',
                                      value: s.solved ? '${s.puzzle.rating}' : '?',
                                      color: Pal.blue,
                                    ),
                                    StatTile(
                                      label: 'streak',
                                      value: '${stats.chessStreak}',
                                      color: Pal.peach,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 14),
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
                  subtitle: s.puzzle.themes.map(ChessPuzzle.themeLabel).join(' · '),
                  stats: [
                    ('rating', _delta >= 0 ? '+$_delta' : '$_delta'),
                    ('puzzle', '${s.puzzle.rating}'),
                    ('time', formatMs(_clock.ms)),
                  ],
                  newBest: false,
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
