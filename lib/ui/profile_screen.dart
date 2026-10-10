import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/level.dart';
import '../services/progress.dart';
import '../services/stats.dart';
import '../theme/palette.dart';
import 'widgets.dart';

class ProfileScreen extends StatelessWidget {
  final Stats stats;
  const ProfileScreen({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final p = stats.progress;
    final unlocked = p.unlocked;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 30),
        children: [
          MochaCard(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CustomPaint(
                    painter: _RingPainter(p.xpIntoLevel / p.xpToNext),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${p.level}',
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1),
                          ),
                          Text(
                            'LEVEL',
                            style: TextStyle(fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: Pal.overlay1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        '${p.xp} XP · ${p.xpToNext - p.xpIntoLevel} to level ${p.level + 1}',
                        style: TextStyle(color: Pal.subtext0, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text('🔥', style: TextStyle(fontSize: 16, color: Pal.peach)),
                          const SizedBox(width: 6),
                          Text(
                            '${p.streak} day streak',
                            style: TextStyle(color: Pal.peach, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: [
              _Tile('Flow', '${stats.totalSolved(GameMode.flow)}', Pal.mauve),
              _Tile('Zip', '${stats.totalSolved(GameMode.zip)}', Pal.blue),
              _Tile('Sudoku', '${stats.totalSolved(GameMode.sudoku)}', Pal.green),
              _Tile('Puzzles', '${stats.chessSolved}', Pal.peach),
              _Tile('Rating', '${stats.chessRating}', Pal.yellow),
              _Tile('Engine', p.bestAiLevel == 0 ? '—' : 'L${p.bestAiLevel}', Pal.red),
            ],
          ),
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'ACHIEVEMENTS · ${unlocked.length}/${Achievement.all.length}',
              style: TextStyle(color: Pal.overlay1, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.4),
            ),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
            children: [
              for (final a in Achievement.all)
                _Badge(a, unlocked: unlocked.contains(a.id)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double t;
  _RingPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 5;
    canvas.drawCircle(c, r, Paint()..color = Pal.surface0..style = PaintingStyle.stroke..strokeWidth = 8);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * t.clamp(0.02, 1),
      false,
      Paint()
        ..color = Pal.mauve
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.t != t;
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Tile(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => MochaCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Pal.overlay1, letterSpacing: 1),
        ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  final Achievement a;
  final bool unlocked;
  const _Badge(this.a, {required this.unlocked});
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: unlocked ? 1 : 0.4,
    child: MochaCard(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: unlocked ? Pal.mauve.withValues(alpha: 0.18) : Pal.surface0,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(unlocked ? a.emoji : '🔒', style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(height: 8),
          Text(
            a.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            a.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Pal.overlay1),
          ),
        ],
      ),
    ),
  );
}
