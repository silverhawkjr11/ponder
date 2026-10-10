import 'package:flutter/material.dart';

import '../game/level.dart';
import '../services/progress.dart';
import '../services/stats.dart';
import '../theme/palette.dart';
import 'chess_screen.dart';
import 'game_screen.dart';
import 'home_screen.dart';
import 'sudoku_screen.dart';
import 'widgets.dart';
import 'zip_game_screen.dart';

/// Today's four puzzles: the same for everyone, once a day.
class DailyScreen extends StatefulWidget {
  final Stats stats;
  const DailyScreen({super.key, required this.stats});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  Future<void> _open(GameMode m) async {
    final seed = Progress.dailySeed();
    final stats = widget.stats;
    final screen = switch (m) {
      GameMode.flow => GameScreen(difficulty: Difficulty.medium, stats: stats, seed: seed, daily: true),
      GameMode.zip => ZipGameScreen(difficulty: Difficulty.medium, stats: stats, seed: seed, daily: true),
      GameMode.sudoku => SudokuScreen(difficulty: Difficulty.medium, stats: stats, seed: seed, daily: true),
      GameMode.chess => ChessScreen(difficulty: Difficulty.medium, stats: stats, puzzleSeed: seed, daily: true),
      GameMode.play => throw UnimplementedError(),
    };
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.stats.progress;
    final done = p.dailyDone();
    final now = DateTime.now();
    final allDone = done.length >= Progress.dailyModes.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 30),
        children: [
          Text(
            '${_months[now.month - 1]} ${now.day}',
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1),
          ),
          const SizedBox(height: 6),
          Text(
            allDone
                ? 'All four done. See you tomorrow.'
                : 'Four medium puzzles, the same for everyone today. +15 XP each, +100 for the set.',
            style: TextStyle(color: Pal.subtext0, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 22),
          for (final m in Progress.dailyModes) ...[
            MochaCard(
              onTap: done.contains(m.name) ? null : () => _open(m),
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (done.contains(m.name) ? Pal.green : Pal.mauve).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      done.contains(m.name) ? Icons.check_rounded : HomeScreen.modeIcons[m],
                      color: done.contains(m.name) ? Pal.green : Pal.mauve,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        Text(
                          done.contains(m.name) ? 'Done' : 'Medium',
                          style: TextStyle(color: Pal.overlay1, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (!done.contains(m.name)) Icon(Icons.chevron_right_rounded, color: Pal.overlay0),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          Center(
            child: Text(
              '${p.dailyCompleted} full set${p.dailyCompleted == 1 ? '' : 's'} completed · 🔥 ${p.streak} day streak',
              style: TextStyle(color: Pal.overlay1, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
