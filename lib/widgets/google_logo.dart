import 'dart:math';

import 'package:flutter/material.dart';

/// Letra "G" de Google en sus cuatro colores, para el botón de inicio de
/// sesión (sin depender de imágenes externas).
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  double _rad(double deg) => deg * pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // Ángulos en grados, sentido horario desde las 3 en punto.
    canvas.drawArc(rect, _rad(0), _rad(45), false, arc(_blue));
    canvas.drawArc(rect, _rad(45), _rad(90), false, arc(_green));
    canvas.drawArc(rect, _rad(135), _rad(70), false, arc(_yellow));
    canvas.drawArc(rect, _rad(205), _rad(112), false, arc(_red));

    // Barra horizontal de la G.
    final center = size.height / 2;
    canvas.drawRect(
      Rect.fromLTRB(
        size.width / 2,
        center - stroke / 2,
        size.width - stroke / 2 + stroke / 2,
        center + stroke / 2,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
