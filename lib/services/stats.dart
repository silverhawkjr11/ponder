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

  String _k(String what, GameMode mode, Difficulty d) =>
      mode == GameMode.flow ? '${what}_${d.name}' : '${what}_zip_${d.name}';

  DifficultyStats of(GameMode mode, Difficulty d) => DifficultyStats(
    solved: _prefs.getInt(_k('solved', mode, d)) ?? 0,
    bestMs: _prefs.getInt(_k('best', mode, d)),
    perfect: _prefs.getInt(_k('perfect', mode, d)) ?? 0,
  );

  int totalSolved(GameMode mode) =>
      Difficulty.values.fold(0, (acc, d) => acc + of(mode, d).solved);

  /// Records a win. Returns true when it set a new best time.
  Future<bool> recordWin(
    GameMode mode,
    Difficulty d, {
    required int ms,
    required bool perfect,
    required bool usedHints,
  }) async {
    final cur = of(mode, d);
    await _prefs.setInt(_k('solved', mode, d), cur.solved + 1);
    if (perfect && !usedHints) {
      await _prefs.setInt(_k('perfect', mode, d), cur.perfect + 1);
    }
    if (usedHints) return false;
    if (cur.bestMs == null || ms < cur.bestMs!) {
      await _prefs.setInt(_k('best', mode, d), ms);
      return true;
    }
    return false;
  }

  bool get haptics => _prefs.getBool('haptics') ?? true;
  Future<void> setHaptics(bool v) => _prefs.setBool('haptics', v);

  /// Classic Flow rule on by default: the board must be completely filled.
  bool get requireFill => _prefs.getBool('require_fill') ?? true;
  Future<void> setRequireFill(bool v) => _prefs.setBool('require_fill', v);

  GameMode get lastMode {
    final n = _prefs.getString('last_mode');
    return GameMode.values.firstWhere(
      (m) => m.name == n,
      orElse: () => GameMode.flow,
    );
  }

  Future<void> setLastMode(GameMode m) => _prefs.setString('last_mode', m.name);
}

String formatMs(int ms) {
  final s = ms ~/ 1000;
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}
