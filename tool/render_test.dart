// Renders screens to PNG for a visual check: flutter test tool/render_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:connect_the_dots/game/level.dart';
import 'package:connect_the_dots/game/zip_board.dart';
import 'package:connect_the_dots/game/zip_generator.dart';
import 'package:connect_the_dots/theme/mocha.dart';
import 'package:connect_the_dots/game/chess_puzzle.dart';
import 'package:connect_the_dots/game/chess_session.dart';
import 'package:connect_the_dots/game/sudoku.dart';
import 'package:connect_the_dots/services/stats.dart';
import 'package:connect_the_dots/ui/chess_board_widget.dart';
import 'package:connect_the_dots/ui/sudoku_screen.dart';
import 'package:connect_the_dots/ui/home_screen.dart';
import 'package:connect_the_dots/ui/zip_board_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dartchess/dartchess.dart' show Square;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> snap(WidgetTester tester, Widget w, String name, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMochaTheme(),
      home: RepaintBoundary(key: key, child: w),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final img = await boundary.toImage(pixelRatio: 1);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File('/tmp/claude-1000/-home-saeed-Desktop-connect-the-dots/7fbdd83a-4904-4a4d-857a-36ed2de8372c/scratchpad/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Nunito');
    for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      final data = File('assets/fonts/Nunito-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(data.buffer)));
    }
    await loader.load();
  });

  testWidgets('zip board mid-play', (tester) async {
    final level = ZipGenerator.generate(Difficulty.medium, seed: 3);
    final board = ZipBoard(level);
    for (var i = 1; i < 11; i++) {
      board.beginDrag(level.solution[i]);
      board.endDrag();
    }
    await tester.runAsync(() => snap(
      tester,
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 380,
            height: 380,
            child: ZipBoardWidget(board: board, haptics: false),
          ),
        ),
      ),
      'zip_board',
      const Size(420, 420),
    ));
  });

  testWidgets('home zip', (tester) async {
    SharedPreferences.setMockInitialValues({'last_mode': 'zip', 'solved_zip_easy': 3, 'best_zip_easy': 41000});
    final stats = await Stats.load();
    await tester.runAsync(() => snap(
      tester,
      HomeScreen(stats: stats),
      'home_zip',
      const Size(430, 980),
    ));
  });

  testWidgets('chess board', (tester) async {
    final p = ChessPuzzle.parse(
      '00008;r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2R1/PqP2bPP/7K b - - 0 24;f2g3 e6e7 b2b1 b3c1 b1c1 h6c1;1811;hangingPiece',
    )!;
    final s = ChessSession(p);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 900));
      s.tap(Square.fromName('e6'));
      await snap(
        tester,
        Scaffold(
          body: Center(
            child: SizedBox(width: 380, height: 380, child: ChessBoardWidget(session: s)),
          ),
        ),
        'chess_board',
        const Size(420, 420),
      );
    });
    s.dispose();
  });

  testWidgets('sudoku screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final stats = await Stats.load();
    tester.view.physicalSize = const Size(430, 930);
    tester.view.devicePixelRatio = 1;
    final key = GlobalKey();
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildMochaTheme(),
        home: RepaintBoundary(key: key, child: SudokuScreen(difficulty: Difficulty.medium, stats: stats)),
      ));
      for (var i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        if (find.text('Undo').evaluate().isNotEmpty) break;
      }
      await tester.tapAt(const Offset(120, 300));
      await tester.pump();
      await tester.tap(find.text('Notes'));
      await tester.pump();
      await tester.tap(find.byWidgetPredicate((w) => w is Text && w.data == '7' && w.style?.fontSize == 22));
      await tester.pump();
      await tester.tap(find.text('Notes'));
      await tester.pump();
      await tester.tapAt(const Offset(260, 420));
      await tester.pump();
      await tester.tap(find.byWidgetPredicate((w) => w is Text && w.data == '5' && w.style?.fontSize == 22));
      await tester.pump(const Duration(milliseconds: 50));
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 1);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('/tmp/claude-1000/-home-saeed-Desktop-connect-the-dots/7fbdd83a-4904-4a4d-857a-36ed2de8372c/scratchpad/sudoku.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });

  testWidgets('home 4 modes', (tester) async {
    SharedPreferences.setMockInitialValues({'last_mode': 'chess', 'chess_rating': 1340, 'chess_solved_easy': 12});
    final stats = await Stats.load();
    await tester.runAsync(() => snap(tester, HomeScreen(stats: stats), 'home4', const Size(430, 980)));
  });
}
