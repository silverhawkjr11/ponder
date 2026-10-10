import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/chess_game.dart';
import '../game/engine.dart';
import '../game/level.dart';
import '../services/progress.dart';
import '../services/stats.dart';
import '../theme/palette.dart';
import 'chess_board_widget.dart';
import 'confetti.dart';
import 'game_chrome.dart';
import 'widgets.dart';

/// A full game against the engine at one ladder level.
class ChessGameScreen extends StatefulWidget {
  final int level;
  final Side? side; // null = random
  final Stats stats;
  final Map<String, dynamic>? resume;
  const ChessGameScreen({
    super.key,
    required this.level,
    required this.side,
    required this.stats,
    this.resume,
  });

  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> with WidgetsBindingObserver {
  EnginePort? _engine;
  ChessGame? _game;
  late int _level = widget.level;
  final GameClock _clock = GameClock();
  Timer? _tick;
  bool _showEnd = false;
  bool _recorded = false;
  Award? _award;
  bool _fallback = false;
  final ScrollController _moveScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && _game != null && !_game!.over) setState(() {});
    });
    _start(resume: widget.resume);
  }

  Future<void> _start({Map<String, dynamic>? resume, int? level}) async {
    final old = _game;
    setState(() => _game = null);
    old?.removeListener(_onGame);
    old?.dispose();
    if (resume == null) widget.stats.clearSave(GameMode.play);
    _engine ??= await StockfishEngine.acquire();
    _fallback = _engine is RandomEngine;
    if (!mounted) return;
    if (level != null) _level = level;
    if (resume != null) _level = (resume['level'] as int?) ?? _level;
    final side = resume != null
        ? (resume['side'] == 'black' ? Side.black : Side.white)
        : widget.side ?? (DateTime.now().microsecond.isEven ? Side.white : Side.black);
    final game = ChessGame(
      engine: _engine!,
      level: EngineLevel.of(_level),
      userSide: side,
      resumeMoves: (resume?['moves'] as List?)?.cast<String>(),
      hints: (resume?['hints'] as int?) ?? 0,
    )..addListener(_onGame);
    setState(() {
      _game = game;
      _showEnd = false;
      _recorded = false;
      _award = null;
      _clock.reset(from: (resume?['ms'] as int?) ?? 0);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _persist();
    _game?.removeListener(_onGame);
    _game?.dispose();
    _moveScroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_game != null && !_game!.over) _clock.start();
    } else {
      _clock.stop();
      _persist();
    }
  }

  void _persist() {
    final g = _game;
    if (g == null) return;
    if (g.over) {
      widget.stats.clearSave(GameMode.play);
      return;
    }
    widget.stats.saveGame(GameMode.play, {
      'd': Difficulty.easy.name,
      'ms': _clock.ms,
      'progress': 'Level $_level · move ${(g.moves.length ~/ 2) + 1}',
      ...g.toJson(),
    });
  }

  void _onGame() {
    final g = _game;
    if (g == null || !mounted) return;
    if (g.lastMove != null && widget.stats.haptics) HapticFeedback.selectionClick();
    if (g.over && !_recorded) {
      _recorded = true;
      _onOver(g);
    }
    setState(() {});
    _persist();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_moveScroll.hasClients) {
        _moveScroll.animateTo(
          _moveScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _onOver(ChessGame g) async {
    _clock.stop();
    widget.stats.clearSave(GameMode.play);
    if (widget.stats.haptics) HapticFeedback.heavyImpact();
    final award = await widget.stats.progress.record(
      ProgressEvent(
        mode: GameMode.play,
        aiLevel: _level,
        aiWin: switch (g.result!.outcome) {
          GameOutcome.win => true,
          GameOutcome.loss => false,
          GameOutcome.draw => null,
        },
        usedHints: g.hintsUsed > 0,
      ),
      chessRating: widget.stats.chessRating,
    );
    if (!mounted) return;
    setState(() => _award = award);
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _showEnd = true);
  }

  Future<void> _resign() async {
    final g = _game;
    if (g == null || g.over) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pal.mantle,
        title: const Text('Resign?'),
        content: const Text('This counts as a loss at this level.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep playing')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Resign', style: TextStyle(color: Pal.red)),
          ),
        ],
      ),
    );
    if (ok == true) g.resign();
  }

  String _status(ChessGame g) {
    if (g.over) {
      return switch (g.result!.outcome) {
        GameOutcome.win => 'You win · ${g.result!.reason}',
        GameOutcome.loss => 'You lose · ${g.result!.reason}',
        GameOutcome.draw => 'Draw · ${g.result!.reason}',
      };
    }
    if (g.thinking) return 'Thinking…';
    return g.pos.isCheck ? 'Your move — check!' : 'Your move';
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final lvl = EngineLevel.of(_level);
    final won = g?.result?.outcome == GameOutcome.win;
    final canNext = won && _level < 10;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                GameTopBar(
                  mode: GameMode.play,
                  difficulty: Difficulty.easy,
                  size: null,
                  title: 'Play · Level $_level',
                  subtitle: g == null
                      ? 'Starting engine…'
                      : '~${lvl.elo} · you are ${g.userSide == Side.white ? 'White' : 'Black'}${_fallback ? ' · engine unavailable' : ''}',
                  time: widget.stats.showTimer ? formatMs(_clock.ms) : null,
                  seed: null,
                ),
                Expanded(
                  child: g == null
                      ? const GeneratingDots()
                      : BoardArea(
                          reserve: 132,
                          board: ChessBoardWidget(session: g),
                          stats: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (g.thinking)
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Pal.mauve),
                                    )
                                  else
                                    Dot(g.userSide == Side.white ? Pal.text : Pal.surface2, size: 12),
                                  const SizedBox(width: 10),
                                  Text(
                                    _status(g),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  if (g.materialBalance != 0) ...[
                                    const SizedBox(width: 10),
                                    Text(
                                      g.materialBalance > 0 ? '+${g.materialBalance}' : '${g.materialBalance}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: g.materialBalance > 0 ? Pal.green : Pal.red,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 28,
                                child: ListView.builder(
                                  controller: _moveScroll,
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  itemCount: (g.sans.length + 1) ~/ 2,
                                  itemBuilder: (_, i) {
                                    final w = g.sans[i * 2];
                                    final b = i * 2 + 1 < g.sans.length ? g.sans[i * 2 + 1] : '';
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '${i + 1}. ',
                                              style: TextStyle(color: Pal.overlay0),
                                            ),
                                            TextSpan(text: '$w  '),
                                            TextSpan(text: b, style: TextStyle(color: Pal.subtext0)),
                                          ],
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      PillButton(
                        icon: Icons.undo_rounded,
                        label: 'Undo',
                        onPressed: g == null || g.thinking || g.moves.isEmpty || (g.over && g.result!.reason == 'Resigned')
                            ? null
                            : g.undo,
                      ),
                      PillButton(
                        icon: Icons.lightbulb_outline_rounded,
                        label: 'Hint',
                        onPressed: g == null || !g.userTurn ? null : () => g.hint(),
                      ),
                      if (g != null && g.over)
                        PillButton(
                          icon: Icons.replay_rounded,
                          label: 'Rematch',
                          onPressed: () => _start(),
                        )
                      else
                        PillButton(
                          icon: Icons.flag_outlined,
                          label: 'Resign',
                          onPressed: g == null ? null : _resign,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (won && _award != null)
              Positioned.fill(child: Confetti(key: ValueKey(_award))),
            if (_showEnd && g != null)
              Positioned.fill(
                child: WinOverlay(
                  title: switch (g.result!.outcome) {
                    GameOutcome.win => 'You win!',
                    GameOutcome.loss => 'You lose',
                    GameOutcome.draw => 'Draw',
                  },
                  subtitle: '${g.result!.reason} · level $_level',
                  stats: [
                    ('moves', '${(g.moves.length + 1) ~/ 2}'),
                    ('time', formatMs(_clock.ms)),
                    ('hints', '${g.hintsUsed}'),
                  ],
                  newBest: false,
                  award: _award,
                  nextLabel: canNext ? 'Next level' : 'Rematch',
                  onNext: () => _start(level: canNext ? _level + 1 : _level),
                  onHome: () => Navigator.of(context).pop(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
