import 'package:shared_preferences/shared_preferences.dart';

import '../game/level.dart';

class DifficultyStats {
  final int solved;
  final int? bestMs;
  final int perfect;
  const DifficultyStats({this.solved = 0, this.bestMs, this.perfect = 0});
}

/// Tiny persistence layer: solved counts, best times, preferences.
class Stats {
  Stats._(this._prefs);
  final SharedPreferences _prefs;

  static Future<Stats> load() async =>
      Stats._(await SharedPreferences.getInstance());

  DifficultyStats of(Difficulty d) => DifficultyStats(
    solved: _prefs.getInt('solved_${d.name}') ?? 0,
    bestMs: _prefs.getInt('best_${d.name}'),
    perfect: _prefs.getInt('perfect_${d.name}') ?? 0,
  );

  int get totalSolved =>
      Difficulty.values.fold(0, (acc, d) => acc + of(d).solved);

  /// Records a win. Returns true when it set a new best time.
  Future<bool> recordWin(
    Difficulty d, {
    required int ms,
    required bool perfect,
    required bool usedHints,
  }) async {
    final cur = of(d);
    await _prefs.setInt('solved_${d.name}', cur.solved + 1);
    if (perfect && !usedHints) {
      await _prefs.setInt('perfect_${d.name}', cur.perfect + 1);
    }
    if (usedHints) return false;
    if (cur.bestMs == null || ms < cur.bestMs!) {
      await _prefs.setInt('best_${d.name}', ms);
      return true;
    }
    return false;
  }

  bool get haptics => _prefs.getBool('haptics') ?? true;
  Future<void> setHaptics(bool v) => _prefs.setBool('haptics', v);

  Difficulty get lastDifficulty {
    final n = _prefs.getString('last_difficulty');
    return Difficulty.values.firstWhere(
      (d) => d.name == n,
      orElse: () => Difficulty.easy,
    );
  }

  Future<void> setLastDifficulty(Difficulty d) =>
      _prefs.setString('last_difficulty', d.name);
}

String formatMs(int ms) {
  final s = ms ~/ 1000;
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}
