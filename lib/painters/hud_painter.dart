import 'dart:math' as math;
import 'package:flutter/material.dart';

class ScoreHudPainter extends CustomPainter {
  final double score;
  final String sceneLabel;
  final String message;
  final bool shouldCapture;

  ScoreHudPainter({required this.score, required this.sceneLabel, required this.message, required this.shouldCapture});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 80), Paint()..color = Colors.black.withValues(alpha: 0.5));

    _text(canvas, sceneLabel, 16, Colors.white, FontWeight.w600, const Offset(16, 30));

    final cx = size.width / 2;
    canvas.drawCircle(Offset(cx, 40), 24, Paint()..color = Colors.white.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 4);
    final sc = shouldCapture ? const Color(0xFF00E676) : score >= 70 ? const Color(0xFFFFD600) : Colors.white;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, 40), radius: 24), -math.pi / 2, (score / 100) * 2 * math.pi, false,
        Paint()..color = sc..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round);
    _text(canvas, '${score.toInt()}', 16, sc, FontWeight.bold, Offset(cx, 40), center: true);

    final mc = shouldCapture ? const Color(0xFF00E676) : Colors.white;
    _text(canvas, message, 14, mc, shouldCapture ? FontWeight.bold : FontWeight.normal, null, rightAlign: true, size: size);
  }

  void _text(Canvas c, String t, double fs, Color color, FontWeight fw, Offset? pos, {bool center = false, bool rightAlign = false, Size? size}) {
    final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(color: color, fontSize: fs, fontWeight: fw)), textDirection: TextDirection.ltr);
    tp.layout();
    if (center && pos != null) { tp.paint(c, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2)); }
    else if (rightAlign && size != null) { tp.paint(c, Offset(size.width - tp.width - 16, 33)); }
    else if (pos != null) { tp.paint(c, pos); }
  }

  @override
  bool shouldRepaint(covariant ScoreHudPainter old) =>
      old.score != score || old.sceneLabel != sceneLabel || old.message != message || old.shouldCapture != shouldCapture;
}
