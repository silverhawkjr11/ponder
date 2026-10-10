import 'package:flutter/material.dart';

import '../game/level.dart';
import '../services/stats.dart';
import '../theme/mocha.dart';
import 'game_screen.dart';
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

  Future<void> _play(Difficulty d) async {
    await widget.stats.setLastMode(_mode);
    if (!mounted) return;
    final mode = _mode;
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, a, _) => mode == GameMode.flow
            ? GameScreen(difficulty: d, stats: widget.stats)
            : ZipGameScreen(difficulty: d, stats: widget.stats),
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

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final accents = {
      Difficulty.easy: Mocha.green,
      Difficulty.medium: Mocha.blue,
      Difficulty.hard: Mocha.peach,
      Difficulty.expert: Mocha.red,
    };
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 36, 22, 24),
          children: [
            const _Hero(),
            const SizedBox(height: 26),
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
                style: const TextStyle(
                  color: Mocha.subtext0,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            for (final d in Difficulty.values) ...[
              _DifficultyCard(
                difficulty: d,
                mode: _mode,
                accent: accents[d]!,
                stats: stats.of(_mode, d),
                onTap: () => _play(d),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            MochaCard(
              padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
              child: Column(
                children: [
                  if (_mode == GameMode.flow) ...[
                  _SettingRow(
                    icon: Icons.grid_on_rounded,
                    title: 'Fill every cell',
                    subtitle: stats.requireFill
                        ? 'Classic rule: pipes must cover the whole board'
                        : 'Relaxed: just connect every pair',
                    value: stats.requireFill,
                    onChanged: (v) async {
                      await stats.setRequireFill(v);
                      if (mounted) setState(() {});
                    },
                  ),
                  const Divider(height: 1, color: Mocha.surface0),
                  ],
                  _SettingRow(
                    icon: Icons.vibration_rounded,
                    title: 'Haptics',
                    subtitle: 'A tap for every connection',
                    value: stats.haptics,
                    onChanged: (v) async {
                      await stats.setHaptics(v);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                stats.totalSolved(_mode) == 0
                    ? 'No ${_mode.label} puzzles solved yet'
                    : '${stats.totalSolved(_mode)} ${_mode.label} puzzle${stats.totalSolved(_mode) == 1 ? '' : 's'} solved',
                style: const TextStyle(
                  color: Mocha.overlay1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
        const _HeroBoard(),
        const SizedBox(height: 22),
        const Text(
          'Dots',
          style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, height: 1),
        ),
        const SizedBox(height: 6),
        Text(
          'Draw lines. Fill grids. No ads.',
          style: TextStyle(
            fontSize: 16,
            color: Mocha.subtext0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// A tiny decorative solved board as the hero image.
class _HeroBoard extends StatelessWidget {
  const _HeroBoard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: CustomPaint(painter: _HeroPainter()),
    );
  }
}

class _HeroPainter extends CustomPainter {
  // Three little pipes drawn on a 4-row strip.
  static const _pipes = [
    (Mocha.mauve, [(0, 0), (0, 1), (1, 1), (1, 2), (0, 2), (0, 3)]),
    (Mocha.blue, [(2, 0), (1, 0), (2, 1), (3, 1), (3, 2), (3, 3), (2, 3)]),
    (Mocha.green, [(1, 3), (2, 2)]),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.height / 3.2;
    Offset at((int, int) p) =>
        Offset(cell * (p.$2 + 0.6), cell * (p.$1 * 0.8 + 0.5));
    final stroke = cell * 0.32;
    for (final (color, pts) in _pipes) {
      final path = Path()..moveTo(at(pts.first).dx, at(pts.first).dy);
      for (final p in pts.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (final e in [pts.first, pts.last]) {
        canvas.drawCircle(at(e), stroke * 0.95, Paint()..color = color);
        canvas.drawCircle(
          at(e).translate(-stroke * 0.25, -stroke * 0.28),
          stroke * 0.4,
          Paint()..color = Colors.white.withValues(alpha: 0.25),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    final sizes = difficulty.sizesFor(mode).map((s) => '$s×$s').join(' · ');
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
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sizes,
                  style: const TextStyle(
                    color: Mocha.overlay1,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                stats.bestMs == null ? '—' : formatMs(stats.bestMs!),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: stats.bestMs == null ? Mocha.overlay0 : Mocha.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '${stats.solved} solved',
                style: const TextStyle(
                  color: Mocha.overlay1,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          const Icon(Icons.chevron_right_rounded, color: Mocha.overlay0),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Mocha.subtext0),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Mocha.overlay1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Mocha.mauve,
            activeTrackColor: Mocha.mauve.withValues(alpha: 0.35),
            inactiveThumbColor: Mocha.overlay0,
            inactiveTrackColor: Mocha.surface0,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  final GameMode mode;
  final ValueChanged<GameMode> onChanged;
  const _ModeSwitch({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Mocha.mantle,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final m in GameMode.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: m == mode ? Mocha.surface0 : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        m == GameMode.flow
                            ? Icons.scatter_plot_rounded
                            : Icons.route_rounded,
                        size: 18,
                        color: m == mode ? Mocha.mauve : Mocha.overlay1,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        m.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: m == mode ? Mocha.text : Mocha.overlay1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
