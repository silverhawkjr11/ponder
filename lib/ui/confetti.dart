import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/mocha.dart';

/// A short burst of falling Mocha-coloured confetti for the win moment.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _Particle {
  final double x, delay, speed, size, drift, spin;
  final Color color;
  final bool round;
  _Particle(Random rng)
      : x = rng.nextDouble(),
        delay = rng.nextDouble() * 0.35,
        speed = 0.6 + rng.nextDouble() * 0.6,
        size = 6 + rng.nextDouble() * 7,
        drift = (rng.nextDouble() - 0.5) * 0.25,
        spin = (rng.nextDouble() - 0.5) * 12,
        color = Mocha.flows[rng.nextInt(Mocha.flows.length)],
        round = rng.nextBool();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();
  final List<_Particle> _parts = List.generate(90, (_) => _Particle(Random()));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _ConfettiPainter(_parts, _c.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> parts;
  final double t;
  _ConfettiPainter(this.parts, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in parts) {
      final lt = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (lt <= 0) continue;
      final y = -40 + (size.height + 80) * Curves.easeIn.transform(lt) * p.speed;
      if (y > size.height + 20) continue;
      final x = size.width * (p.x + p.drift * lt) +
          sin(lt * 6 + p.spin) * 12;
      final fade = lt > 0.75 ? (1 - lt) / 0.25 : 1.0;
      paint.color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(lt * p.spin);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
