import 'package:flutter/material.dart';
import '../services/yolo_service.dart';

class GuidePainter extends CustomPainter {
  final List<Detection> detections;

  GuidePainter({required this.detections});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < detections.length; i++) {
      var det = detections[i];

      Color boxColor = _getColorForIndex(i);
      final boxPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawRect(det.rect, boxPaint);

      String labelText = "${det.label} ${(det.confidence * 100).toStringAsFixed(1)}%";
      final textPainter = TextPainter(
        text: TextSpan(text: labelText, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();

      final textBgRect = Rect.fromLTWH(det.rect.left, det.rect.top - 25, textPainter.width + 10, 25);
      canvas.drawRect(textBgRect, Paint()..color = boxColor.withOpacity(0.8));
      textPainter.paint(canvas, Offset(det.rect.left + 5, det.rect.top - 22));
    }
  }

  Color _getColorForIndex(int index) {
    List<Color> colors = [Colors.greenAccent, Colors.redAccent, Colors.cyanAccent, Colors.orangeAccent, Colors.amberAccent];
    return colors[index % colors.length];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}