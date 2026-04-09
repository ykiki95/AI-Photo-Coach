import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/scene_classifier.dart';
import '../utils/composition_scorer.dart';

class ContourGuidePainter extends CustomPainter {
  final List<DetectedObject> objects;
  final CompositionResult? composition;
  final SceneType sceneType;
  final double? horizonY;

  ContourGuidePainter({
    required this.objects,
    this.composition,
    required this.sceneType,
    this.horizonY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (objects.isEmpty) return;

    _drawRuleOfThirdsGrid(canvas, size);

    for (final obj in objects) {
      if (obj.contour != null && obj.contour!.length >= 3) {
        _drawContour(canvas, size, obj.contour!, Colors.white, 2.5);
      } else {
        _drawBox(canvas, size, obj.normalizedBox, Colors.white, 2.0);
      }
    }

    if (composition != null && objects.isNotEmpty) {
      final mainObj = objects.first;
      final guidePos = composition!.guidePosition;

      if (mainObj.contour != null && mainObj.contour!.length >= 3) {
        final movedContour = _moveContour(mainObj.contour!, mainObj.center, guidePos);
        _drawContour(canvas, size, movedContour, const Color(0xFF00E676), 2.0, isDashed: true);
      } else {
        final movedBox = _moveBox(mainObj.normalizedBox, mainObj.center, guidePos);
        _drawBox(canvas, size, movedBox, const Color(0xFF00E676), 2.0, isDashed: true);
      }

      if (composition!.moveDirection != 'none' &&
          composition!.moveDirection != 'closer' &&
          composition!.moveDirection != 'farther') {
        _drawArrow(canvas, size, mainObj.center, guidePos);
      }
    }

    if (sceneType == SceneType.landscape && horizonY != null) {
      _drawHorizonLine(canvas, size, horizonY!);
      if (composition != null) {
        _drawHorizonGuide(canvas, size, composition!.guidePosition.dy);
      }
    }
  }

  void _drawRuleOfThirdsGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (int i = 1; i <= 2; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawContour(Canvas canvas, Size size, List<Offset> contour,
      Color color, double strokeWidth, {bool isDashed = false}) {
    if (contour.length < 3) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final first = Offset(contour[0].dx * size.width, contour[0].dy * size.height);
    path.moveTo(first.dx, first.dy);
    for (int i = 1; i < contour.length; i++) {
      final p = Offset(contour[i].dx * size.width, contour[i].dy * size.height);
      path.lineTo(p.dx, p.dy);
    }
    path.close();

    if (isDashed) {
      _drawDashedPath(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _drawBox(Canvas canvas, Size size, Rect normBox, Color color,
      double strokeWidth, {bool isDashed = false}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTRB(
      normBox.left * size.width, normBox.top * size.height,
      normBox.right * size.width, normBox.bottom * size.height,
    );

    if (isDashed) {
      final path = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)));
      _drawDashedPath(canvas, path, paint);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final segLen = draw ? 8.0 : 5.0;
        final end = (distance + segLen).clamp(0.0, metric.length);
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, end), paint);
        }
        distance = end;
        draw = !draw;
      }
    }
  }

  List<Offset> _moveContour(List<Offset> contour, Offset fromCenter, Offset toCenter) {
    final dx = toCenter.dx - fromCenter.dx;
    final dy = toCenter.dy - fromCenter.dy;
    return contour.map((p) => Offset((p.dx + dx).clamp(0.0, 1.0), (p.dy + dy).clamp(0.0, 1.0))).toList();
  }

  Rect _moveBox(Rect box, Offset fromCenter, Offset toCenter) {
    final dx = toCenter.dx - fromCenter.dx;
    final dy = toCenter.dy - fromCenter.dy;
    return Rect.fromLTRB(
      (box.left + dx).clamp(0.0, 1.0), (box.top + dy).clamp(0.0, 1.0),
      (box.right + dx).clamp(0.0, 1.0), (box.bottom + dy).clamp(0.0, 1.0),
    );
  }

  void _drawArrow(Canvas canvas, Size size, Offset from, Offset to) {
    final paint = Paint()
      ..color = const Color(0xFF00E676)..strokeWidth = 2.5
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final fromPx = Offset(from.dx * size.width, from.dy * size.height);
    final toPx = Offset(to.dx * size.width, to.dy * size.height);
    canvas.drawLine(fromPx, toPx, paint);
    final angle = (toPx - fromPx).direction;
    final p1 = Offset(toPx.dx - 12 * Offset.fromDirection(angle - 0.5).dx, toPx.dy - 12 * Offset.fromDirection(angle - 0.5).dy);
    final p2 = Offset(toPx.dx - 12 * Offset.fromDirection(angle + 0.5).dx, toPx.dy - 12 * Offset.fromDirection(angle + 0.5).dy);
    canvas.drawLine(toPx, p1, paint);
    canvas.drawLine(toPx, p2, paint);
  }

  void _drawHorizonLine(Canvas canvas, Size size, double y) {
    final paint = Paint()..color = Colors.white..strokeWidth = 2.0..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, y * size.height), Offset(size.width, y * size.height), paint);
  }

  void _drawHorizonGuide(Canvas canvas, Size size, double guideY) {
    final paint = Paint()..color = const Color(0xFF00E676)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final py = guideY * size.height;
    double x = 0;
    bool draw = true;
    while (x < size.width) {
      if (draw) canvas.drawLine(Offset(x, py), Offset((x + 8).clamp(0, size.width), py), paint);
      x += draw ? 8 : 5;
      draw = !draw;
    }
  }

  @override
  bool shouldRepaint(covariant ContourGuidePainter old) {
    return old.objects != objects || old.composition != composition ||
        old.sceneType != sceneType || old.horizonY != horizonY;
  }
}
