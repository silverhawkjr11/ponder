// One-off: `flutter test tool/make_icons_test.dart` renders legacy PNG
// launcher icons (the adaptive icon is a vector drawable).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('render icons', () async {
    const sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final e in sizes.entries) {
      final px = e.value.toDouble();
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, px, px), Radius.circular(px * 0.22)),
        Paint()..color = const Color(0xFF1E1E2E),
      );
      // Same geometry as the vector, in a 108 viewport scaled to fill.
      canvas.scale(px / 108);
      canvas.translate(-10, -10);
      canvas.scale(1.22);
      void tile(double x, double y) => canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 28, 28), const Radius.circular(4)),
        Paint()..color = const Color(0xFF181825),
      );
      tile(22, 22); tile(58, 22); tile(22, 58); tile(58, 58);
      Paint stroke(Color c, double w) => Paint()
        ..color = c..style = PaintingStyle.stroke..strokeWidth = w
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
      // flow
      const mauve = Color(0xFFCBA6F7), blue = Color(0xFF89B4FA), green = Color(0xFFA6E3A1), peach = Color(0xFFFAB387);
      canvas.drawPath(Path()..moveTo(31, 33)..lineTo(45, 33)..lineTo(45, 47), stroke(mauve, 4));
      canvas.drawCircle(const Offset(31, 33), 3.6, Paint()..color = mauve);
      canvas.drawCircle(const Offset(45, 47), 3.6, Paint()..color = mauve);
      // zip
      canvas.drawPath(Path()..moveTo(63, 32)..lineTo(77, 32)..lineTo(77, 40)..lineTo(63, 40)..lineTo(63, 48)..lineTo(77, 48), stroke(blue, 3.2));
      canvas.drawCircle(const Offset(63, 32), 3.2, Paint()..color = blue);
      canvas.drawCircle(const Offset(77, 48), 3.2, Paint()..color = blue);
      // pawn
      canvas.drawCircle(const Offset(38, 64), 3.4, Paint()..color = green);
      canvas.drawPath(Path()..moveTo(34.8, 68.5)..lineTo(41.2, 68.5)..lineTo(43.4, 76)..lineTo(32.6, 76)..close(), Paint()..color = green);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(29, 77.5, 18, 4), const Radius.circular(1.5)), Paint()..color = green);
      // sudoku
      final thin = Paint()..color = peach.withValues(alpha: 0.7)..strokeWidth = 1.2..style = PaintingStyle.stroke;
      canvas.drawRect(const Rect.fromLTWH(61, 61, 18, 18), thin);
      for (final k in [67.0, 73.0]) {
        canvas.drawLine(Offset(k, 61), Offset(k, 79), thin);
        canvas.drawLine(Offset(61, k), Offset(79, k), thin);
      }
      for (final (x, y) in [(62.2, 62.2), (74.2, 68.2), (68.2, 74.2)]) {
        canvas.drawRect(Rect.fromLTWH(x, y, 3.6, 3.6), Paint()..color = peach);
      }
      final img = await rec.endRecording().toImage(e.value, e.value);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      await File('android/app/src/main/res/mipmap-${e.key}/ic_launcher.png').writeAsBytes(bytes!.buffer.asUint8List());
    }
  });
}
