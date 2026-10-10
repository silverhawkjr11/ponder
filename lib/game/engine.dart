import 'dart:async';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:stockfish/stockfish.dart';

/// One rung of the ladder: how the engine is throttled at that level.
class EngineLevel {
  final int number; // 1..10
  final int skill; // Stockfish Skill Level 0..20
  final int? depth;
  final int? moveTimeMs;
  final double blunder; // chance to play a random legal move instead
  final int elo; // rough label
  const EngineLevel(this.number, this.skill, {this.depth, this.moveTimeMs, this.blunder = 0, required this.elo});

  static const ladder = [
    EngineLevel(1, 0, depth: 1, blunder: 0.35, elo: 400),
    EngineLevel(2, 1, depth: 1, blunder: 0.2, elo: 600),
    EngineLevel(3, 3, depth: 2, blunder: 0.1, elo: 800),
    EngineLevel(4, 5, depth: 3, elo: 1000),
    EngineLevel(5, 8, depth: 4, elo: 1200),
    EngineLevel(6, 11, depth: 6, elo: 1450),
    EngineLevel(7, 14, depth: 8, elo: 1700),
    EngineLevel(8, 17, depth: 10, elo: 1950),
    EngineLevel(9, 20, depth: 13, elo: 2200),
    EngineLevel(10, 20, moveTimeMs: 1500, elo: 2500),
  ];

  static EngineLevel of(int n) => ladder[(n - 1).clamp(0, ladder.length - 1)];
}

/// Anything that can pick a move. Lets tests and the fallback skip Stockfish.
abstract class EnginePort {
  Future<String?> bestMove(String fen, EngineLevel level);
  Future<String?> analyse(String fen);
  void dispose() {}
}

/// Picks random legal moves. Used when the native engine can't start.
class RandomEngine implements EnginePort {
  final Random _rng = Random();
  String? _random(String fen) {
    final pos = Chess.fromSetup(Setup.parseFen(fen));
    final moves = <NormalMove>[];
    for (final e in pos.legalMoves.entries) {
      for (final to in e.value.squares) {
        final piece = pos.board.pieceAt(e.key);
        if (piece?.role == Role.pawn && (to.rank == 0 || to.rank == 7)) {
          moves.add(NormalMove(from: e.key, to: to, promotion: Role.queen));
        } else {
          moves.add(NormalMove(from: e.key, to: to));
        }
      }
    }
    if (moves.isEmpty) return null;
    return moves[_rng.nextInt(moves.length)].uci;
  }

  @override
  Future<String?> bestMove(String fen, EngineLevel level) async => _random(fen);
  @override
  Future<String?> analyse(String fen) async => _random(fen);
  @override
  void dispose() {}
}

/// Stockfish behind a tiny UCI driver. Requests are serialised.
class StockfishEngine implements EnginePort {
  StockfishEngine._();
  static StockfishEngine? _instance;
  static Future<EnginePort> acquire() async {
    _instance ??= StockfishEngine._();
    final ok = await _instance!._start();
    return ok ? _instance! : RandomEngine();
  }

  Stockfish? _sf;
  final _lines = StreamController<String>.broadcast();
  Future<bool>? _starting;
  Future<void> _queue = Future.value();
  final Random _rng = Random();

  Future<bool> _start() {
    return _starting ??= () async {
      try {
        final sf = Stockfish();
        _sf = sf;
        sf.stdout.listen(_lines.add);
        final ready = Completer<bool>();
        void check() {
          if (sf.state.value == StockfishState.ready && !ready.isCompleted) ready.complete(true);
          if (sf.state.value == StockfishState.error && !ready.isCompleted) ready.complete(false);
        }
        sf.state.addListener(check);
        check();
        final ok = await ready.future.timeout(const Duration(seconds: 15), onTimeout: () => false);
        sf.state.removeListener(check);
        if (!ok) return false;
        await _send('uci', until: (l) => l.startsWith('uciok'));
        _sf!.stdin = 'setoption name Threads value 1';
        _sf!.stdin = 'setoption name Hash value 16';
        await _send('isready', until: (l) => l.startsWith('readyok'));
        return true;
      } catch (_) {
        return false;
      }
    }();
  }

  Future<String> _send(String cmd, {required bool Function(String) until}) {
    final c = Completer<String>();
    late StreamSubscription sub;
    sub = _lines.stream.listen((l) {
      if (until(l) && !c.isCompleted) {
        c.complete(l);
        sub.cancel();
      }
    });
    _sf!.stdin = cmd;
    return c.future.timeout(const Duration(seconds: 30), onTimeout: () {
      sub.cancel();
      return '';
    });
  }

  Future<T> _serial<T>(Future<T> Function() f) {
    final next = _queue.then((_) => f());
    _queue = next.then((_) {}, onError: (_) {});
    return next;
  }

  @override
  Future<String?> bestMove(String fen, EngineLevel level) => _serial(() async {
    if (level.blunder > 0 && _rng.nextDouble() < level.blunder) {
      return RandomEngine()._random(fen);
    }
    _sf!.stdin = 'setoption name Skill Level value ${level.skill}';
    _sf!.stdin = 'ucinewgame';
    _sf!.stdin = 'position fen $fen';
    final go = level.moveTimeMs != null ? 'go movetime ${level.moveTimeMs}' : 'go depth ${level.depth}';
    final line = await _send(go, until: (l) => l.startsWith('bestmove'));
    return _parse(line);
  });

  @override
  Future<String?> analyse(String fen) => _serial(() async {
    _sf!.stdin = 'setoption name Skill Level value 20';
    _sf!.stdin = 'position fen $fen';
    final line = await _send('go movetime 700', until: (l) => l.startsWith('bestmove'));
    return _parse(line);
  });

  String? _parse(String line) {
    final parts = line.split(' ');
    if (parts.length < 2 || parts[1] == '(none)' || parts[1].isEmpty) return null;
    return parts[1];
  }

  @override
  void dispose() {}
}
