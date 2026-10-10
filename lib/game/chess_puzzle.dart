import 'dart:math';

import 'package:flutter/services.dart';

import 'level.dart';

/// One tactic from the Lichess puzzle database (CC0). [moves] are UCI; the
/// first one is the opponent's move that sets up the position, the rest is
/// the solution, with the opponent's replies interleaved.
class ChessPuzzle {
  final String id;
  final String fen;
  final List<String> moves;
  final int rating;
  final List<String> themes;

  const ChessPuzzle({
    required this.id,
    required this.fen,
    required this.moves,
    required this.rating,
    required this.themes,
  });

  static ChessPuzzle? parse(String line) {
    final parts = line.split(';');
    if (parts.length < 4) return null;
    return ChessPuzzle(
      id: parts[0],
      fen: parts[1],
      moves: parts[2].split(' '),
      rating: int.tryParse(parts[3]) ?? 1500,
      themes: parts.length > 4 && parts[4].isNotEmpty ? parts[4].split(' ') : const [],
    );
  }

  /// Human label for a Lichess theme tag, e.g. mateIn2 -> "Mate in 2".
  static String themeLabel(String t) {
    final m = RegExp(r'^mateIn(\d)$').firstMatch(t);
    if (m != null) return 'Mate in ${m.group(1)}';
    final words = t.replaceAllMapped(RegExp(r'([A-Z])'), (x) => ' ${x.group(1)!.toLowerCase()}');
    return words[0].toUpperCase() + words.substring(1);
  }
}

/// Rating band per difficulty.
extension ChessBand on Difficulty {
  (int, int) get ratingBand => switch (this) {
    Difficulty.easy => (0, 1200),
    Difficulty.medium => (1200, 1600),
    Difficulty.hard => (1600, 2000),
    Difficulty.expert => (2000, 9999),
  };

  String get ratingLabel => switch (this) {
    Difficulty.easy => 'under 1200',
    Difficulty.medium => '1200 – 1600',
    Difficulty.hard => '1600 – 2000',
    Difficulty.expert => '2000+',
  };
}

/// Loads the bundled puzzle file once and hands out random puzzles per band.
class ChessPuzzles {
  ChessPuzzles._(this._lines, this._byBand);
  final List<String> _lines;
  final Map<Difficulty, List<int>> _byBand;

  static ChessPuzzles? _instance;

  static Future<ChessPuzzles> load() async {
    if (_instance != null) return _instance!;
    final raw = await rootBundle.loadString('assets/puzzles/puzzles.txt');
    final lines = raw.split('\n').where((l) => l.isNotEmpty).toList();
    final byBand = {for (final d in Difficulty.values) d: <int>[]};
    for (var i = 0; i < lines.length; i++) {
      // Rating is the 4th field; avoid parsing the whole line.
      final parts = lines[i].split(';');
      final rating = int.tryParse(parts[3]) ?? 1500;
      for (final d in Difficulty.values) {
        final (lo, hi) = d.ratingBand;
        if (rating >= lo && rating < hi) byBand[d]!.add(i);
      }
    }
    return _instance = ChessPuzzles._(lines, byBand);
  }

  int countFor(Difficulty d) => _byBand[d]!.length;

  ChessPuzzle pick(Difficulty d, {Set<String> avoid = const {}, Random? rng}) {
    final r = rng ?? Random();
    final pool = _byBand[d]!;
    for (var tries = 0; tries < 50; tries++) {
      final p = ChessPuzzle.parse(_lines[pool[r.nextInt(pool.length)]]);
      if (p != null && !avoid.contains(p.id)) return p;
    }
    return ChessPuzzle.parse(_lines[pool[r.nextInt(pool.length)]])!;
  }

  ChessPuzzle? byId(String id) {
    for (final l in _lines) {
      if (l.startsWith('$id;')) return ChessPuzzle.parse(l);
    }
    return null;
  }
}
