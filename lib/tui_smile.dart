import 'package:flutter/material.dart';

/// Logo "smile" TUI dessiné en code (swoosh + point), couleur rouge TUI.
class TuiSmile extends StatelessWidget {
  final double size;
  final Color color;
  const TuiSmile({super.key, this.size = 48, this.color = const Color(0xFFD6004F)});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SmilePainter(color)),
    );
  }
}

class _SmilePainter extends CustomPainter {
  final Color color;
  _SmilePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = w * 0.16;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Swoosh : barre horizontale gauche → grande courbe (smile) → remontée droite
    final path = Path();
    path.moveTo(w * 0.08, h * 0.40);
    path.lineTo(w * 0.26, h * 0.40);
    path.cubicTo(
      w * 0.30, h * 0.96, // contrôle bas-gauche
      w * 0.74, h * 0.96, // contrôle bas-droite
      w * 0.88, h * 0.50, // fin (remontée à droite)
    );
    canvas.drawPath(path, paint);

    // Point (le "i") en haut à droite
    canvas.drawCircle(
      Offset(w * 0.88, h * 0.16),
      w * 0.10,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SmilePainter old) => old.color != color;
}
