import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/detected_object.dart';
import '../services/contour_extractor.dart';

class GuidePainter extends CustomPainter {
  final List<CompositionGuide> guides;
  final List<List<Offset>> contours;
  final Size imageSize;
  final Size widgetSize;

  GuidePainter({
    required this.guides,
    required this.contours,
    required this.imageSize,
    required this.widgetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawThirdsGrid(canvas, size);

    final scaleX = widgetSize.width / imageSize.width;
    final scaleY = widgetSize.height / imageSize.height;

    for (int i = 0; i < guides.length; i++) {
      final guide = guides[i];
      final contour = (i < contours.length && contours[i].length >= 10)
          ? contours[i]
          : <Offset>[];

      if (guide.needsMove) {
        _drawGuideContour(canvas, guide, contour, scaleX, scaleY);
        _drawMoveArrow(canvas, guide, scaleX, scaleY);
      } else {
        _drawGoodBadge(canvas, guide, scaleX, scaleY);
      }
    }
  }

  void _drawGuideContour(
      Canvas canvas, CompositionGuide guide, List<Offset> contour,
      double scaleX, double scaleY,
      ) {
    final dashPaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF22C55E).withOpacity(0.06);

    final offsetX = (guide.idealCenter.dx - guide.object.center.dx) * scaleX;
    final offsetY = (guide.idealCenter.dy - guide.object.center.dy) * scaleY;

    if (contour.isNotEmpty) {
      final movedPts = contour.map((p) => Offset(
        p.dx * scaleX + offsetX,
        p.dy * scaleY + offsetY,
      )).toList();

      final path = _buildSmoothPath(movedPts);
      canvas.drawPath(path, fillPaint);
      _drawDashedPath(canvas, path, dashPaint, 10, 6);
    } else {
      final bbox = guide.object.boundingBox;
      final movedRect = Rect.fromCenter(
        center: Offset(guide.idealCenter.dx * scaleX, guide.idealCenter.dy * scaleY),
        width: bbox.width * scaleX,
        height: bbox.height * scaleY,
      );
      canvas.drawOval(movedRect, fillPaint);
      _drawDashedOval(canvas, movedRect, dashPaint, 10, 6);
    }

    _drawLabel(canvas, '여기로 이동',
        Offset(guide.idealCenter.dx * scaleX, guide.idealBounds.top * scaleY - 18),
        const Color(0xFF22C55E));
  }

  void _drawMoveArrow(Canvas canvas, CompositionGuide guide, double sx, double sy) {
    final from = Offset(guide.object.center.dx * sx, guide.object.center.dy * sy);
    final to = Offset(guide.idealCenter.dx * sx, guide.idealCenter.dy * sy);
    final dist = (to - from).distance;
    if (dist < 30) return;

    final dx = (to.dx - from.dx) / dist;
    final dy = (to.dy - from.dy) / dist;
    final start = Offset(from.dx + dx * 50, from.dy + dy * 50);
    final end = Offset(to.dx - dx * 50, to.dy - dy * 50);
    if ((end - start).distance < 25) return;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    _drawDashedLine(canvas, start, end, paint, 10, 6);

    final angle = atan2(end.dy - start.dy, end.dx - start.dx);
    final head = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(end.dx - 12 * cos(angle - 0.4), end.dy - 12 * sin(angle - 0.4))
      ..lineTo(end.dx - 12 * cos(angle + 0.4), end.dy - 12 * sin(angle + 0.4))
      ..close();
    canvas.drawPath(head, Paint()..color = Colors.white.withOpacity(0.8)..style = PaintingStyle.fill);
  }

  void _drawGoodBadge(Canvas canvas, CompositionGuide guide, double sx, double sy) {
    _drawLabel(canvas, '좋은 위치! ✓',
        Offset(guide.object.center.dx * sx, guide.object.boundingBox.bottom * sy + 22),
        const Color(0xFF22C55E));
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

  void _drawThirdsGrid(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.12)..strokeWidth = 0.5;
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    final bg = RRect.fromRectAndRadius(
      Rect.fromCenter(center: pos, width: tp.width + 18, height: tp.height + 10),
      const Radius.circular(8),
    );
    canvas.drawRRect(bg, Paint()..color = Colors.black.withOpacity(0.5));
    canvas.drawRRect(bg, Paint()..color = color.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 1);
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, double dash, double gap) {
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, (d + dash).clamp(0, m.length)), paint);
        d += dash + gap;
      }
    }
  }

  void _drawDashedOval(Canvas canvas, Rect rect, Paint paint, double dash, double gap) {
    _drawDashedPath(canvas, Path()..addOval(rect), paint, dash, gap);
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint, double dash, double gap) {
    final dist = (b - a).distance;
    final dx = (b.dx - a.dx) / dist;
    final dy = (b.dy - a.dy) / dist;
    double d = 0;
    while (d < dist) {
      final e = (d + dash).clamp(0.0, dist);
      canvas.drawLine(Offset(a.dx + dx * d, a.dy + dy * d), Offset(a.dx + dx * e, a.dy + dy * e), paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant GuidePainter old) => true;
}