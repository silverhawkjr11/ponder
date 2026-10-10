import 'package:flutter/material.dart';

import '../game/chess_puzzle.dart';
import '../game/level.dart';
import '../services/stats.dart';
import '../theme/palette.dart';
import 'chess_screen.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'sudoku_screen.dart';
import 'widgets.dart';
import 'zip_game_screen.dart';

class HomeScreen extends StatefulWidget {
  final Stats stats;
  const HomeScreen({super.key, required this.stats});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late GameMode _mode = widget.stats.lastMode;

  static const modeIcons = {
    GameMode.flow: Icons.scatter_plot_rounded,
    GameMode.zip: Icons.route_rounded,
    GameMode.chess: Icons.castle_rounded,
    GameMode.sudoku: Icons.grid_3x3_rounded,
  };

  Widget _screenFor(GameMode mode, Difficulty d, Map<String, dynamic>? resume) =>
      switch (mode) {
        GameMode.flow => GameScreen(difficulty: d, stats: widget.stats, resume: resume),
        GameMode.zip => ZipGameScreen(difficulty: d, stats: widget.stats, resume: resume),
        GameMode.chess => ChessScreen(difficulty: d, stats: widget.stats, resume: resume),
        GameMode.sudoku => SudokuScreen(difficulty: d, stats: widget.stats, resume: resume),
      };

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, a, _) => screen,
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _play(Difficulty d) async {
    await widget.stats.setLastMode(_mode);
    if (!mounted) return;
    await _open(_screenFor(_mode, d, null));
  }

  Future<void> _resume(GameMode mode, Map<String, dynamic> save) async {
    final d = Difficulty.values.firstWhere(
      (x) => x.name == save['d'],
      orElse: () => Difficulty.easy,
    );
    await _open(_screenFor(mode, d, save));
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final accents = {
      Difficulty.easy: Pal.green,
      Difficulty.medium: Pal.blue,
      Difficulty.hard: Pal.peach,
      Difficulty.expert: Pal.red,
    };
    final saves = <(GameMode, Map<String, dynamic>)>[
      for (final m in GameMode.values)
        if (stats.savedGame(m) case final s?) (m, s),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: _Hero()),
                IconButton(
                  onPressed: () => _open(SettingsScreen(stats: stats)),
                  icon: Icon(Icons.settings_rounded, color: Pal.overlay1),
                  tooltip: 'Settings',
                ),
              ],
            ),
            if (saves.isNotEmpty) ...[
              const SizedBox(height: 22),
              _Label('Continue'),
              for (final (m, s) in saves)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ContinueCard(
                    mode: m,
                    save: s,
                    onTap: () => _resume(m, s),
                    onDismiss: () async {
                      await stats.clearSave(m);
                      if (mounted) setState(() {});
                    },
                  ),
                ),
            ],
            const SizedBox(height: 18),
            _ModeSwitch(
              mode: _mode,
              onChanged: (m) {
                setState(() => _mode = m);
                stats.setLastMode(m);
              },
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 14),
              child: Text(
                _mode.tagline,
                style: TextStyle(color: Pal.subtext0, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            for (final d in Difficulty.values) ...[
              _DifficultyCard(
                difficulty: d,
                mode: _mode,
                accent: accents[d]!,
                stats: _mode == GameMode.chess
                    ? DifficultyStats(solved: stats.chessSolvedIn(d))
                    : stats.of(_mode, d),
                onTap: () => _play(d),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 10),
            if (_mode == GameMode.chess)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: Text(
                    'Puzzle rating ${stats.chessRating}   ·   streak ${stats.chessStreak}',
                    style: TextStyle(color: Pal.mauve, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            Center(
              child: Text(
                _solvedLine(stats),
                style: TextStyle(color: Pal.overlay1, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _solvedLine(Stats stats) {
    final n = _mode == GameMode.chess ? stats.chessSolved : stats.totalSolved(_mode);
    if (n == 0) return 'No ${_mode.label} puzzles solved yet';
    return '$n ${_mode.label} puzzle${n == 1 ? '' : 's'} solved';
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Pal.overlay1,
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 1.4,
      ),
    ),
  );
}

class _ContinueCard extends StatelessWidget {
  final GameMode mode;
  final Map<String, dynamic> save;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _ContinueCard({
    required this.mode,
    required this.save,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final d = Difficulty.values.firstWhere(
      (x) => x.name == save['d'],
      orElse: () => Difficulty.easy,
    );
    final ms = (save['ms'] as int?) ?? 0;
    final progress = (save['progress'] as String?) ?? '';
    return MochaCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
      color: Pal.mauve.withValues(alpha: Pal.p.light ? 0.10 : 0.12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Pal.mauve.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(_HomeScreenState.modeIcons[mode], color: Pal.mauve, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${mode.label} · ${d.label}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  '$progress   ·   ${formatMs(ms)}',
                  style: TextStyle(color: Pal.subtext0, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
          Icon(Icons.play_arrow_rounded, color: Pal.mauve),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(Icons.close_rounded, color: Pal.overlay0, size: 20),
            tooltip: 'Discard',
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 110, child: CustomPaint(painter: _HeroPainter())),
        const SizedBox(height: 20),
        const Text(
          'Ponder',
          style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, height: 1),
        ),
        const SizedBox(height: 6),
        Text(
          'Four little puzzles. No ads.',
          style: TextStyle(fontSize: 16, color: Pal.subtext0, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Four small tiles, one per game, echoing the launcher icon.
class _HeroPainter extends CustomPainter {
  const _HeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final t = size.height * 0.46; // tile size
    final gap = size.height * 0.08;
    final tiles = [
      Offset(0, 0),
      Offset(t + gap, 0),
      Offset(0, t + gap),
      Offset(t + gap, t + gap),
    ];
    final colors = [Pal.mauve, Pal.blue, Pal.green, Pal.peach];
    for (var i = 0; i < 4; i++) {
      final r = tiles[i] & Size(t, t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(t * 0.26)),
        Paint()..color = Pal.mantle,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(t * 0.26)),
        Paint()
          ..color = colors[i].withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      final c = colors[i];
      final s = t * 0.14;
      final stroke = Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final fill = Paint()..color = c;
      switch (i) {
        case 0: // flow: L pipe with two dots
          final a = r.topLeft + Offset(t * 0.28, t * 0.3);
          final b = r.topLeft + Offset(t * 0.72, t * 0.7);
          final path = Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(b.dx, a.dy)
            ..lineTo(b.dx, b.dy);
          canvas.drawPath(path, stroke);
          canvas.drawCircle(a, s * 0.9, fill);
          canvas.drawCircle(b, s * 0.9, fill);
        case 1: // zip: zigzag path, numbered ends
          final p1 = r.topLeft + Offset(t * 0.26, t * 0.3);
          final p2 = r.topLeft + Offset(t * 0.74, t * 0.3);
          final p3 = r.topLeft + Offset(t * 0.74, t * 0.52);
          final p4 = r.topLeft + Offset(t * 0.26, t * 0.52);
          final p5 = r.topLeft + Offset(t * 0.26, t * 0.74);
          final p6 = r.topLeft + Offset(t * 0.74, t * 0.74);
          final path = Path()..moveTo(p1.dx, p1.dy);
          for (final p in [p2, p3, p4, p5, p6]) {
            path.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(path, stroke..strokeWidth = s * 0.7);
          canvas.drawCircle(p1, s * 0.85, fill);
          canvas.drawCircle(p6, s * 0.85, fill);
        case 2: // chess: a pawn
          final cx = r.center.dx;
          final top = r.top + t * 0.22;
          canvas.drawCircle(Offset(cx, top + t * 0.1), t * 0.1, fill);
          final body = Path()
            ..moveTo(cx - t * 0.1, top + t * 0.22)
            ..lineTo(cx + t * 0.1, top + t * 0.22)
            ..lineTo(cx + t * 0.16, top + t * 0.46)
            ..lineTo(cx - t * 0.16, top + t * 0.46)
            ..close();
          canvas.drawPath(body, fill);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(cx, top + t * 0.52), width: t * 0.46, height: t * 0.1),
              Radius.circular(t * 0.04),
            ),
            fill,
          );
        case 3: // sudoku: 3x3 grid with a few filled cells
          final g = t * 0.6;
          final o = r.center - Offset(g / 2, g / 2);
          final cell = g / 3;
          final thin = Paint()
            ..color = c.withValues(alpha: 0.6)
            ..strokeWidth = 1.5;
          for (var k = 0; k <= 3; k++) {
            canvas.drawLine(Offset(o.dx + k * cell, o.dy), Offset(o.dx + k * cell, o.dy + g), thin);
            canvas.drawLine(Offset(o.dx, o.dy + k * cell), Offset(o.dx + g, o.dy + k * cell), thin);
          }
          for (final (rr, cc) in [(0, 0), (1, 2), (2, 1)]) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(o.dx + cc * cell, o.dy + rr * cell, cell, cell).deflate(cell * 0.2),
                Radius.circular(cell * 0.2),
              ),
              fill,
            );
          }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ModeSwitch extends StatelessWidget {
  final GameMode mode;
  final ValueChanged<GameMode> onChanged;
  const _ModeSwitch({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.95,
      children: [
        for (final m in GameMode.values)
          GestureDetector(
            onTap: () => onChanged(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: m == mode ? Pal.surface0 : Pal.mantle,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: m == mode ? Pal.mauve.withValues(alpha: 0.6) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _HomeScreenState.modeIcons[m],
                    size: 26,
                    color: m == mode ? Pal.mauve : Pal.overlay1,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: m == mode ? Pal.text : Pal.overlay1,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final Difficulty difficulty;
  final GameMode mode;
  final Color accent;
  final DifficultyStats stats;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.difficulty,
    required this.mode,
    required this.accent,
    required this.stats,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sizes = switch (mode) {
      GameMode.flow || GameMode.zip =>
        difficulty.sizesFor(mode).map((s) => '$s×$s').join(' · '),
      GameMode.chess => 'rated ${difficulty.ratingLabel}',
      GameMode.sudoku => '${difficulty.sudokuClues} clues',
    };
    return MochaCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Dot(accent, size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  difficulty.label,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  sizes,
                  style: TextStyle(color: Pal.overlay1, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (mode != GameMode.chess)
                Text(
                  stats.bestMs == null ? '—' : formatMs(stats.bestMs!),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: stats.bestMs == null ? Pal.overlay0 : Pal.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              Text(
                '${stats.solved} solved',
                style: TextStyle(color: Pal.overlay1, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Icon(Icons.chevron_right_rounded, color: Pal.overlay0),
        ],
      ),
    );
  }
}
