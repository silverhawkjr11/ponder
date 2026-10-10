// `flutter test tool/zip_bench_test.dart` prints Zip generation timings.
// ignore_for_file: avoid_print
import 'package:connect_the_dots/game/level.dart';
import 'package:connect_the_dots/game/zip_generator.dart';
import 'package:connect_the_dots/game/zip_solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bench', () {
    final out = StringBuffer();
    for (final d in Difficulty.values) {
      for (var seed = 0; seed < 6; seed++) {
        final sw = Stopwatch()..start();
        final l = ZipGenerator.generate(d, seed: seed);
        final gen = sw.elapsedMilliseconds;
        final c = ZipSolver(l, budget: 3000000).count(limit: 2);
        out.writeln('${d.label} ${l.size}x${l.size} numbers ${l.numberCount} walls ${l.walls.length} gen ${gen}ms solutions $c');
      }
    }
    final l = ZipGenerator.generate(Difficulty.medium, seed: 3);
    final g = l.numberGrid();
    for (var r = 0; r < l.size; r++) {
      final row = StringBuffer();
      for (var c = 0; c < l.size; c++) {
        row.write(g[r][c] == 0 ? ' .' : g[r][c].toString().padLeft(2));
        row.write(c < l.size - 1 && l.hasWall(Cell(r, c), Cell(r, c + 1)) ? '|' : ' ');
      }
      out.writeln(row);
      if (r < l.size - 1) {
        final sep = StringBuffer();
        for (var c = 0; c < l.size; c++) {
          sep.write(l.hasWall(Cell(r, c), Cell(r + 1, c)) ? '--' : '  ');
          sep.write(' ');
        }
        out.writeln(sep);
      }
    }
    print(out);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
