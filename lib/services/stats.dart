import 'dart:convert';
import 'dart:math' as math;

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

  // ---- Chess ---------------------------------------------------------

  int get chessRating => _prefs.getInt('chess_rating') ?? 1200;
  int get chessSolved => _prefs.getInt('chess_solved') ?? 0;
  int get chessStreak => _prefs.getInt('chess_streak') ?? 0;
  int chessSolvedIn(Difficulty d) => _prefs.getInt('chess_solved_${d.name}') ?? 0;

  Set<String> get chessSeen =>
      (_prefs.getStringList('chess_seen') ?? const []).toSet();

  /// Elo-style update against the puzzle's rating. Returns the delta.
  Future<int> recordChess(
    Difficulty d, {
    required int puzzleRating,
    required bool clean,
    required String id,
  }) async {
    final r = chessRating;
    final expected = 1 / (1 + math.pow(10, (puzzleRating - r) / 400));
    final k = chessSolved < 20 ? 40 : 24;
    final delta = (k * ((clean ? 1 : 0) - expected)).round();
    await _prefs.setInt('chess_rating', r + delta);
    await _prefs.setInt('chess_solved', chessSolved + 1);
    await _prefs.setInt('chess_solved_${d.name}', chessSolvedIn(d) + 1);
    await _prefs.setInt('chess_streak', clean ? chessStreak + 1 : 0);
    final seen = _prefs.getStringList('chess_seen') ?? [];
    seen.add(id);
    if (seen.length > 600) seen.removeRange(0, seen.length - 600);
    await _prefs.setStringList('chess_seen', seen);
    return delta;
  }

  // ---- Settings ------------------------------------------------------

  String? get themeName => _prefs.getString('theme');
  Future<void> setThemeName(String v) => _prefs.setString('theme', v);

  bool get showMistakes => _prefs.getBool('show_mistakes') ?? true;
  Future<void> setShowMistakes(bool v) => _prefs.setBool('show_mistakes', v);

  bool get showTimer => _prefs.getBool('show_timer') ?? true;
  Future<void> setShowTimer(bool v) => _prefs.setBool('show_timer', v);

  bool get autoQueen => _prefs.getBool('auto_queen') ?? false;
  Future<void> setAutoQueen(bool v) => _prefs.setBool('auto_queen', v);

  Future<void> resetStats() async {
    for (final k in _prefs.getKeys().toList()) {
      if (k.startsWith('solved') || k.startsWith('best') || k.startsWith('perfect') || k.startsWith('chess_')) {
        await _prefs.remove(k);
      }
    }
  }

  // ---- Saved games ---------------------------------------------------

  Map<String, dynamic>? savedGame(GameMode mode) {
    final raw = _prefs.getString('save_${mode.name}');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveGame(GameMode mode, Map<String, dynamic> data) =>
      _prefs.setString('save_${mode.name}', jsonEncode(data));

  Future<void> clearSave(GameMode mode) => _prefs.remove('save_${mode.name}');

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
