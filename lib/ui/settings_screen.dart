import 'package:flutter/material.dart';

import '../services/stats.dart';
import '../theme/palette.dart';
import 'widgets.dart';

class SettingsScreen extends StatefulWidget {
  final Stats stats;
  const SettingsScreen({super.key, required this.stats});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Stats get stats => widget.stats;

  Future<void> _set(Future<void> Function() f) async {
    await f();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 30),
        children: [
          _Section('Theme'),
          MochaCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final p in Palette.all)
                  _ThemeRow(
                    palette: p,
                    selected: Pal.p == p,
                    onTap: () => _set(() async {
                      themeController.palette = p;
                      await stats.setThemeName(p.name);
                    }),
                  ),
              ],
            ),
          ),
          _Section('General'),
          MochaCard(
            padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.vibration_rounded,
                  title: 'Haptics',
                  subtitle: 'A tap for every connection',
                  value: stats.haptics,
                  onChanged: (v) => _set(() => stats.setHaptics(v)),
                ),
                const _Line(),
                SettingRow(
                  icon: Icons.timer_outlined,
                  title: 'Show timer',
                  subtitle: 'Hide it if it stresses you out',
                  value: stats.showTimer,
                  onChanged: (v) => _set(() => stats.setShowTimer(v)),
                ),
              ],
            ),
          ),
          _Section('Flow'),
          MochaCard(
            padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
            child: SettingRow(
              icon: Icons.grid_on_rounded,
              title: 'Fill every cell',
              subtitle: stats.requireFill
                  ? 'Classic rule: pipes must cover the whole board'
                  : 'Relaxed: just connect every pair',
              value: stats.requireFill,
              onChanged: (v) => _set(() => stats.setRequireFill(v)),
            ),
          ),
          _Section('Chess'),
          MochaCard(
            padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
            child: SettingRow(
              icon: Icons.auto_awesome_rounded,
              title: 'Always promote to queen',
              subtitle: 'Skip the piece picker on promotion',
              value: stats.autoQueen,
              onChanged: (v) => _set(() => stats.setAutoQueen(v)),
            ),
          ),
          _Section('Sudoku'),
          MochaCard(
            padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
            child: SettingRow(
              icon: Icons.error_outline_rounded,
              title: 'Show mistakes',
              subtitle: 'Wrong digits turn red as you place them',
              value: stats.showMistakes,
              onChanged: (v) => _set(() => stats.setShowMistakes(v)),
            ),
          ),
          _Section('Data'),
          MochaCard(
            padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Pal.mantle,
                  title: const Text('Reset statistics?'),
                  content: const Text(
                    'Solved counts, best times, chess rating and streak go back to zero. Saved games stay.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Keep'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Reset', style: TextStyle(color: Pal.red)),
                    ),
                  ],
                ),
              );
              if (ok == true) await _set(stats.resetStats);
            },
            child: Row(
              children: [
                Icon(Icons.restart_alt_rounded, size: 20, color: Pal.red),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Reset statistics',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Pal.red),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Pal.overlay0),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Center(
            child: Text(
              'Ponder · chess puzzles from Lichess (CC0) · engine: Stockfish 11 (GPLv3) · pieces: cburnett (CC BY-SA)',
              style: TextStyle(color: Pal.overlay0, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 18, 0, 8),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        color: Pal.overlay1,
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 1.4,
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line();
  @override
  Widget build(BuildContext context) => Divider(height: 1, color: Pal.surface0);
}

class _ThemeRow extends StatelessWidget {
  final Palette palette;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeRow({required this.palette, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Pal.surface0 : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.base,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.surface1, width: 1.5),
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final c in [palette.mauve, palette.blue, palette.green])
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                palette.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            if (selected) Icon(Icons.check_rounded, color: Pal.mauve),
          ],
        ),
      ),
    );
  }
}

/// Toggle row shared by home and settings.
class SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingRow({
    super.key,
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
          Icon(icon, size: 20, color: Pal.subtext0),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.5, color: Pal.overlay1, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Pal.mauve,
            activeTrackColor: Pal.mauve.withValues(alpha: 0.35),
            inactiveThumbColor: Pal.overlay0,
            inactiveTrackColor: Pal.surface0,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
