import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/detected_object.dart';
import '../services/contour_extractor.dart';

class ContourPainter extends CustomPainter {
  final List<DetectedObjectInfo> objects;
  final List<List<Offset>> contours;
  final Size imageSize;
  final Size widgetSize;

  ContourPainter({
    required this.objects,
    required this.contours,
    required this.imageSize,
    required this.widgetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    for (int i = 0; i < objects.length && i < contours.length; i++) {
      final pts = contours[i];

      if (pts.length >= 10) {
        final widgetPts = ContourSmoother.toWidgetCoords(pts, imageSize, widgetSize);
        final path = _buildSmoothPath(widgetPts);
        canvas.drawPath(path, glowPaint);
        canvas.drawPath(path, outlinePaint);
      }

      _drawLabel(canvas, objects[i]);
    }
  }

  Path _buildSmoothPath(List<Offset> pts) {
    final path = Path();
    if (pts.length < 3) return path;
    path.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length - 1; i += 2) {
      final ctrl = pts[i];
      final end = pts[(i + 1).clamp(0, pts.length - 1)];
      path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
    }
    path.close();
    return path;
  }

  void _drawLabel(Canvas canvas, DetectedObjectInfo obj) {
    final sx = widgetSize.width / imageSize.width;
    final sy = widgetSize.height / imageSize.height;
    final tp = TextPainter(
      text: TextSpan(text: obj.label,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = obj.boundingBox.center.dx * sx - tp.width / 2;
    final y = obj.boundingBox.top * sy - 26;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x - 8, y - 3, tp.width + 16, tp.height + 6), const Radius.circular(6)),
      Paint()..color = Colors.black.withOpacity(0.6),
    );
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant ContourPainter old) => true;
}