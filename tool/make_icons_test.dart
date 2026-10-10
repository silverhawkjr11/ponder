// One-off: `flutter test tool/make_icons_test.dart` renders legacy PNG
// launcher icons for devices below Android 8 (the adaptive icon is a vector).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('render icons', () async {
    const sizes = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final e in sizes.entries) {
      final px = e.value.toDouble();
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      final s = px / 108;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, px, px), Radius.circular(px * 0.22)),
        Paint()..color = const Color(0xFF1E1E2E),
      );
      canvas.scale(s);
      void pipe(List<Offset> pts, Color c, double w, double r) {
        final p = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (final o in pts.skip(1)) {
          p.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(
          p,
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = w
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.drawCircle(pts.first, r, Paint()..color = c);
        canvas.drawCircle(pts.last, r, Paint()..color = c);
      }
      pipe([const Offset(30, 36), const Offset(56, 36), const Offset(56, 72), const Offset(78, 72)], const Color(0xFFCBA6F7), 10, 10);
      pipe([const Offset(78, 36), const Offset(78, 52)], const Color(0xFF89B4FA), 8, 7.5);
      pipe([const Offset(30, 56), const Offset(30, 72)], const Color(0xFFA6E3A1), 8, 7.5);
      final img = await rec.endRecording().toImage(e.value, e.value);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File('android/app/src/main/res/mipmap-${e.key}/ic_launcher.png');
      await f.writeAsBytes(bytes!.buffer.asUint8List());
    }
  });
}
