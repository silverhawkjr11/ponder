import 'package:shared_preferences/shared_preferences.dart';

import '../game/level.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String emoji;
  const Achievement(this.id, this.title, this.description, this.emoji);

  static const all = [
    Achievement('first_flow', 'First flow', 'Solve a Flow puzzle', '🔗'),
    Achievement('first_zip', 'Zipped', 'Solve a Zip puzzle', '🧵'),
    Achievement('first_sudoku', 'Nine by nine', 'Solve a Sudoku', '🔢'),
    Achievement('first_puzzle', 'Tactician', 'Solve a chess puzzle', '♞'),
    Achievement('first_win', 'Checkmate', 'Beat the engine', '♔'),
    Achievement('solves_10', 'Warming up', 'Solve 10 puzzles', '✨'),
    Achievement('solves_50', 'Regular', 'Solve 50 puzzles', '🌙'),
    Achievement('solves_200', 'Devoted', 'Solve 200 puzzles', '🌟'),
    Achievement('streak_3', 'Three in a row', 'Play 3 days running', '🔥'),
    Achievement('streak_7', 'One week', 'Play 7 days running', '🔥'),
    Achievement('streak_30', 'One month', 'Play 30 days running', '🔥'),
    Achievement('flow_expert_perfect', 'Clean lines', 'Perfect an Expert Flow', '💎'),
    Achievement('zip_one_stroke', 'One stroke', 'Hard Zip in a single stroke', '🖊️'),
    Achievement('sudoku_flawless', 'Flawless', 'Expert Sudoku, no mistakes, no hints', '🧠'),
    Achievement('rating_1500', 'Club player', 'Puzzle rating 1500', '📈'),
    Achievement('rating_1800', 'Strong', 'Puzzle rating 1800', '📈'),
    Achievement('rating_2100', 'Fearsome', 'Puzzle rating 2100', '📈'),
    Achievement('ai_5', 'Halfway up', 'Beat engine level 5', '🪜'),
    Achievement('ai_10', 'Top of the ladder', 'Beat engine level 10', '🏆'),
    Achievement('daily_7', 'Daily habit', 'Finish 7 daily challenges', '📅'),
  ];
}

/// What a single solve or game is worth.
class ProgressEvent {
  final GameMode mode;
  final Difficulty? difficulty;
  final bool perfect;
  final bool usedHints;
  final int? puzzleRating;
  final int? aiLevel;
  final bool? aiWin; // null = draw
  final bool daily;
  const ProgressEvent({
    required this.mode,
    this.difficulty,
    this.perfect = false,
    this.usedHints = false,
    this.puzzleRating,
    this.aiLevel,
    this.aiWin,
    this.daily = false,
  });
}

class Award {
  final int xp;
  final int levelBefore;
  final int levelAfter;
  final List<Achievement> unlocked;
  final bool dailyComplete;
  const Award(this.xp, this.levelBefore, this.levelAfter, this.unlocked, this.dailyComplete);
  bool get leveledUp => levelAfter > levelBefore;
}

/// XP, levels, titles, streaks, achievements and daily challenge bookkeeping.
class Progress {
  Progress(this._prefs);
  final SharedPreferences _prefs;

  int get xp => _prefs.getInt('xp') ?? 0;
  int get streak => _prefs.getInt('streak') ?? 0;
  String? get lastDay => _prefs.getString('last_day');
  int get dailyCompleted => _prefs.getInt('daily_complete') ?? 0;
  Set<String> get unlocked => (_prefs.getStringList('achievements') ?? const []).toSet();
  int get totalSolves => _prefs.getInt('total_solves') ?? 0;
  int aiWins(int level) => _prefs.getInt('ai_wins_$level') ?? 0;
  int aiGames(int level) => _prefs.getInt('ai_games_$level') ?? 0;
  int aiDraws(int level) => _prefs.getInt('ai_draws_$level') ?? 0;
  int get bestAiLevel {
    var best = 0;
    for (var l = 1; l <= 10; l++) {
      if (aiWins(l) > 0) best = l;
    }
    return best;
  }

  bool aiUnlocked(int level) => level == 1 || aiWins(level - 1) > 0;

  // ---- Levels ---------------------------------------------------------

  /// Total XP needed to reach [level]: 100, 300, 600, 1000, ...
  static int xpFor(int level) => level <= 1 ? 0 : 50 * (level - 1) * level;

  static int levelFor(int xp) {
    var l = 1;
    while (xpFor(l + 1) <= xp) {
      l++;
    }
    return l;
  }

  int get level => levelFor(xp);
  int get xpIntoLevel => xp - xpFor(level);
  int get xpToNext => xpFor(level + 1) - xpFor(level);

  static String titleFor(int level) {
    if (level >= 50) return 'Legend';
    if (level >= 40) return 'Grandmaster';
    if (level >= 30) return 'Master';
    if (level >= 20) return 'Expert';
    if (level >= 15) return 'Strategist';
    if (level >= 10) return 'Tactician';
    if (level >= 6) return 'Solver';
    if (level >= 3) return 'Apprentice';
    return 'Newcomer';
  }

  String get title => titleFor(level);

  // ---- Daily ---------------------------------------------------------

  static String todayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Deterministic seed for today's puzzles.
  static int dailySeed([DateTime? now]) {
    final k = todayKey(now);
    var h = 7;
    for (final c in k.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  static const dailyModes = [GameMode.flow, GameMode.zip, GameMode.sudoku, GameMode.chess];

  Set<String> dailyDone([DateTime? now]) =>
      (_prefs.getStringList('daily_${todayKey(now)}') ?? const []).toSet();

  // ---- Recording -----------------------------------------------------

  static int baseXp(ProgressEvent e) {
    if (e.mode == GameMode.play) {
      final l = e.aiLevel ?? 1;
      return e.aiWin == true ? 20 + l * 25 : (e.aiWin == null ? 5 + l * 8 : 5);
    }
    final d = e.difficulty ?? Difficulty.easy;
    final table = switch (e.mode) {
      GameMode.flow || GameMode.zip => const [10, 20, 35, 50],
      GameMode.sudoku => const [15, 30, 50, 80],
      GameMode.chess => const [15, 25, 40, 60],
      GameMode.play => const [0, 0, 0, 0],
    };
    var xp = table[d.index];
    if (e.perfect && !e.usedHints) xp = (xp * 1.5).round();
    if (e.usedHints) xp = (xp * 0.6).round();
    return xp;
  }

  Future<Award> record(ProgressEvent e, {required int chessRating}) async {
    final before = level;
    var gained = baseXp(e);
    final newly = <Achievement>[];
    final have = unlocked;

    void unlock(String id) {
      if (have.contains(id)) return;
      have.add(id);
      newly.add(Achievement.all.firstWhere((a) => a.id == id));
    }

    // Streak.
    final today = todayKey();
    final last = lastDay;
    if (last != today) {
      final yesterday = todayKey(DateTime.now().subtract(const Duration(days: 1)));
      final s = last == yesterday ? streak + 1 : 1;
      await _prefs.setInt('streak', s);
      await _prefs.setString('last_day', today);
    }
    if (streak >= 3) unlock('streak_3');
    if (streak >= 7) unlock('streak_7');
    if (streak >= 30) unlock('streak_30');

    // Counters and per-event achievements.
    if (e.mode == GameMode.play) {
      final l = e.aiLevel ?? 1;
      await _prefs.setInt('ai_games_$l', aiGames(l) + 1);
      if (e.aiWin == true) {
        await _prefs.setInt('ai_wins_$l', aiWins(l) + 1);
        unlock('first_win');
        if (l >= 5) unlock('ai_5');
        if (l >= 10) unlock('ai_10');
      } else if (e.aiWin == null) {
        await _prefs.setInt('ai_draws_$l', aiDraws(l) + 1);
      }
    } else {
      final total = totalSolves + 1;
      await _prefs.setInt('total_solves', total);
      if (total >= 10) unlock('solves_10');
      if (total >= 50) unlock('solves_50');
      if (total >= 200) unlock('solves_200');
      switch (e.mode) {
        case GameMode.flow:
          unlock('first_flow');
          if (e.difficulty == Difficulty.expert && e.perfect && !e.usedHints) unlock('flow_expert_perfect');
        case GameMode.zip:
          unlock('first_zip');
          if (e.difficulty!.index >= Difficulty.hard.index && e.perfect && !e.usedHints) unlock('zip_one_stroke');
        case GameMode.sudoku:
          unlock('first_sudoku');
          if (e.difficulty == Difficulty.expert && e.perfect && !e.usedHints) unlock('sudoku_flawless');
        case GameMode.chess:
          unlock('first_puzzle');
          if (chessRating >= 1500) unlock('rating_1500');
          if (chessRating >= 1800) unlock('rating_1800');
          if (chessRating >= 2100) unlock('rating_2100');
        case GameMode.play:
          break;
      }
    }

    // Daily challenge.
    var dailyComplete = false;
    if (e.daily) {
      final done = dailyDone()..add(e.mode.name);
      await _prefs.setStringList('daily_$today', done.toList());
      gained += 15;
      if (done.length >= dailyModes.length && !(_prefs.getBool('daily_bonus_$today') ?? false)) {
        await _prefs.setBool('daily_bonus_$today', true);
        await _prefs.setInt('daily_complete', dailyCompleted + 1);
        gained += 100;
        dailyComplete = true;
        if (dailyCompleted >= 7) unlock('daily_7');
      }
    }

    await _prefs.setInt('xp', xp + gained);
    await _prefs.setStringList('achievements', have.toList());
    return Award(gained, before, level, newly, dailyComplete);
  }
}
