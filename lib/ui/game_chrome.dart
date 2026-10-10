import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/level.dart';
import '../services/progress.dart';
import '../theme/palette.dart';
import 'widgets.dart';

/// Pieces shared by both game screens: header, stat tiles, win card, loader.

class GameTopBar extends StatelessWidget {
  final GameMode mode;
  final Difficulty difficulty;
  final int? size;
  final String? time;
  final int? seed;
  final String? subtitle;
  final String? title;
  const GameTopBar({
    super.key,
    required this.mode,
    required this.difficulty,
    required this.size,
    required this.time,
    required this.seed,
    this.subtitle,
    this.title,
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
                  title ?? '${mode.label} · ${difficulty.label}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle ??
                      (size == null ? 'Generating…' : '$size × $size   ·   #$seed'),
                  style: TextStyle(
                    color: Pal.overlay1,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (time != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Pal.mantle,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 18, color: Pal.subtext0),
                const SizedBox(width: 6),
                Text(
                  time!,
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

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

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
              color: color ?? Pal.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Pal.overlay1,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class GameButtons extends StatelessWidget {
  final VoidCallback? onRestart;
  final VoidCallback? onHint;
  final VoidCallback? onNew;
  const GameButtons({super.key, this.onRestart, this.onHint, this.onNew});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          PillButton(
            icon: Icons.refresh_rounded,
            label: 'Restart',
            onPressed: onRestart,
          ),
          PillButton(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Hint',
            onPressed: onHint,
          ),
          PillButton(
            icon: Icons.shuffle_rounded,
            label: 'New',
            onPressed: onNew,
          ),
        ],
      ),
    );
  }
}

class WinOverlay extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<(String, String)> stats;
  final bool newBest;
  final Award? award;
  final String nextLabel;
  final VoidCallback onNext;
  final VoidCallback onHome;

  const WinOverlay({
    super.key,
    required this.title,
    this.subtitle,
    required this.stats,
    required this.newBest,
    this.award,
    this.nextLabel = 'Next puzzle',
    required this.onNext,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Container(
        color: Pal.crust.withValues(alpha: 0.62 * t.clamp(0, 1)),
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
                  for (final c in [Pal.red, Pal.yellow, Pal.green, Pal.blue, Pal.mauve])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Dot(c, size: 12),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Pal.subtext0,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              if (newBest)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Pal.yellow.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'New best time',
                      style: TextStyle(
                        color: Pal.yellow,
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
                  for (final (label, value) in stats)
                    Column(
                      children: [
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            color: Pal.overlay1,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (award != null) ...[
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _Chip('+${award!.xp} XP', Pal.mauve),
                    if (award!.leveledUp)
                      _Chip('Level ${award!.levelAfter} · ${Progress.titleFor(award!.levelAfter)}', Pal.yellow),
                    if (award!.dailyComplete) _Chip('Daily complete +100', Pal.green),
                    for (final a in award!.unlocked) _Chip('${a.emoji} ${a.title}', Pal.teal),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: PillButton(
                  icon: Icons.arrow_forward_rounded,
                  label: nextLabel,
                  color: Pal.mauve,
                  foreground: Pal.crust,
                  onPressed: onNext,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onHome,
                child: Text(
                  'Home',
                  style: TextStyle(
                    color: Pal.subtext0,
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

/// Three bouncing dots while a level is generated.
class GeneratingDots extends StatefulWidget {
  const GeneratingDots({super.key});

  @override
  State<GeneratingDots> createState() => _GeneratingDotsState();
}

class _GeneratingDotsState extends State<GeneratingDots>
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
    final colors = [Pal.mauve, Pal.blue, Pal.green];
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

/// Square board area plus a stats row underneath, centred in the free space.
class BoardArea extends StatelessWidget {
  final Widget board;
  final Widget stats;
  final double reserve;
  const BoardArea({super.key, required this.board, required this.stats, this.reserve = 104});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final side = math.min(c.maxWidth - 20, c.maxHeight - reserve);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: side, height: side, child: board),
              const SizedBox(height: 20),
              stats,
            ],
          ),
        );
      },
    );
  }
}

/// Stopwatch with a resumable offset.
class GameClock {
  final Stopwatch _sw = Stopwatch();
  int base = 0;
  int get ms => base + _sw.elapsedMilliseconds;
  void start() => _sw.start();
  void stop() => _sw.stop();
  void reset({int from = 0}) {
    base = from;
    _sw
      ..reset()
      ..start();
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
    ),
  );
}
