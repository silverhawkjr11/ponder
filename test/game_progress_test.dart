import 'package:connect_the_dots/game/chess_game.dart';
import 'package:connect_the_dots/game/engine.dart';
import 'package:connect_the_dots/game/level.dart';
import 'package:connect_the_dots/services/progress.dart';
import 'package:connect_the_dots/services/stats.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Replies with a fixed script, then random.
class ScriptedEngine implements EnginePort {
  final List<String> script;
  final RandomEngine _fallback = RandomEngine();
  ScriptedEngine(this.script);
  @override
  Future<String?> bestMove(String fen, EngineLevel level) async =>
      script.isNotEmpty ? script.removeAt(0) : _fallback.bestMove(fen, level);
  @override
  Future<String?> analyse(String fen) async => 'e2e4';
  @override
  void dispose() {}
}

void main() {
  test("fool's mate against a scripted engine", () async {
    final g = ChessGame(engine: ScriptedEngine(['f2f3', 'g2g4']), level: EngineLevel.of(1), userSide: Side.black);
    await Future.delayed(Duration.zero); // engine plays f3
    expect(g.userTurn, isTrue);
    expect(g.lastMove!.uci, 'f2f3');
    g.tap(Square.fromName('e7'));
    g.tap(Square.fromName('e5'));
    await Future.delayed(Duration.zero); // g4
    g.tap(Square.fromName('d8'));
    g.tap(Square.fromName('h4'));
    expect(g.over, isTrue);
    expect(g.result!.outcome, GameOutcome.win);
    expect(g.result!.reason, 'Checkmate');
    expect(g.toJson()['moves'], ['f2f3', 'e7e5', 'g2g4', 'd8h4']);
    g.dispose();
  });

  test('undo takes back a pair of plies and resume replays', () async {
    final g = ChessGame(engine: ScriptedEngine(['e7e5', 'g8f6']), level: EngineLevel.of(1), userSide: Side.white);
    g.tap(Square.fromName('e2'));
    g.tap(Square.fromName('e4'));
    await Future.delayed(Duration.zero);
    expect(g.moves.length, 2);
    g.undo();
    expect(g.moves, isEmpty);
    g.tap(Square.fromName('d2'));
    g.tap(Square.fromName('d4'));
    await Future.delayed(Duration.zero);
    final saved = g.toJson();
    final r = ChessGame(
      engine: ScriptedEngine([]),
      level: EngineLevel.of(1),
      userSide: Side.white,
      resumeMoves: (saved['moves'] as List).cast<String>(),
    );
    expect(r.moves.length, 2);
    expect(r.userTurn, isTrue);
    g.dispose();
    r.dispose();
  });

  test('progress: xp, levels, streak, achievements, daily', () async {
    SharedPreferences.setMockInitialValues({});
    final stats = await Stats.load();
    final p = stats.progress;
    expect(p.level, 1);
    expect(Progress.levelFor(100), 2);
    expect(Progress.levelFor(299), 2);
    expect(Progress.levelFor(300), 3);
    var a = await p.record(
      const ProgressEvent(mode: GameMode.flow, difficulty: Difficulty.easy, perfect: true),
      chessRating: 1200,
    );
    expect(a.xp, 15);
    expect(a.unlocked.map((x) => x.id), contains('first_flow'));
    expect(p.streak, 1);
    a = await p.record(
      const ProgressEvent(mode: GameMode.play, aiLevel: 5, aiWin: true),
      chessRating: 1200,
    );
    expect(a.xp, 145);
    expect(a.unlocked.map((x) => x.id), containsAll(['first_win', 'ai_5']));
    expect(p.aiUnlocked(6), isTrue);
    expect(p.aiUnlocked(7), isFalse);
    expect(p.level, 2);
    expect(a.leveledUp, isTrue);
    for (final m in Progress.dailyModes) {
      a = await p.record(ProgressEvent(mode: m, difficulty: Difficulty.medium, daily: true), chessRating: 1200);
    }
    expect(a.dailyComplete, isTrue);
    expect(p.dailyCompleted, 1);
    expect(p.dailyDone().length, 4);
  });
}
