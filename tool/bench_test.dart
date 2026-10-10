// Not a real test: `flutter test tool/bench_test.dart` prints generation timings.
// ignore_for_file: avoid_print
import 'package:connect_the_dots/game/generator.dart';
import 'package:connect_the_dots/game/level.dart';
import 'package:connect_the_dots/game/solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bench', () {
    final out = StringBuffer();
    for (final d in Difficulty.values) {
      for (var seed = 100; seed < 106; seed++) {
        final sw = Stopwatch()..start();
        final l = LevelGenerator.generate(d, seed: seed);
        final gen = sw.elapsedMilliseconds;
        final c = FlowSolver(l, budget: 3000000).count(limit: 2);
        out.writeln('${d.label} ${l.size}x${l.size} colors ${l.colorCount} gen ${gen}ms solutions $c');
      }
    }
    print(out);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
