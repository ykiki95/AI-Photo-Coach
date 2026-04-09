import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/scene_classifier.dart';
import '../utils/composition_scorer.dart';

/// 사물의 정밀 외곽선(흰색)과 가이드 위치(초록색)를 그리는 CustomPainter
class ContourGuidePainter extends CustomPainter {
  final List<DetectedObject> objects;
  final CompositionResult? composition;
  final SceneType sceneType;
  final double? horizonY; // 풍경 모드 수평선 (정규화 0~1)

  ContourGuidePainter({
    required this.objects,
    this.composition,
    required this.sceneType,
    this.horizonY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (objects.isEmpty) return;

    // === 1) 삼분법 격자선 (연한 회색, 가느다란 선) ===
    _drawRuleOfThirdsGrid(canvas, size);

    // === 2) 사물 외곽선 (흰색 실선) ===
    for (final obj in objects) {
      if (obj.contour != null && obj.contour!.length >= 3) {
        _drawContour(canvas, size, obj.contour!, Colors.white, 2.5);
      } else {
        // 외곽선이 없으면 박스 fallback (흰색)
        _drawBox(canvas, size, obj.normalizedBox, Colors.white, 2.0);
      }
    }

    // === 3) 가이드 위치 (초록색) ===
    if (composition != null && objects.isNotEmpty) {
      final mainObj = objects.first;
      final guidePos = composition!.guidePosition;

      if (mainObj.contour != null && mainObj.contour!.length >= 3) {
        // 외곽선을 가이드 위치로 이동시켜 초록색으로 표시
        final movedContour = _moveContour(
          mainObj.contour!,
          mainObj.center,
          guidePos,
        );
        _drawContour(canvas, size, movedContour, 
            const Color(0xFF00E676), 2.0, isDashed: true);
      } else {
        // 박스를 가이드 위치로 이동
        final movedBox = _moveBox(mainObj.normalizedBox, mainObj.center, guidePos);
        _drawBox(canvas, size, movedBox, 
            const Color(0xFF00E676), 2.0, isDashed: true);
      }

      // === 4) 이동 화살표 ===
      if (composition!.moveDirection != 'none' &&
          composition!.moveDirection != 'closer' &&
          composition!.moveDirection != 'farther') {
        _drawArrow(canvas, size, mainObj.center, guidePos);
      }
    }

    // === 5) 풍경 모드 수평선 ===
    if (sceneType == SceneType.landscape && horizonY != null) {
      _drawHorizonLine(canvas, size, horizonY!);
      if (composition != null) {
        _drawHorizonGuide(canvas, size, composition!.guidePosition.dy);
      }
    }
  }

  /// 삼분법 격자선
  void _drawRuleOfThirdsGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 2; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  /// 외곽선 그리기
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

  /// 박스 그리기
  void _drawBox(Canvas canvas, Size size, Rect normBox, Color color,
      double strokeWidth, {bool isDashed = false}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTRB(
      normBox.left * size.width,
      normBox.top * size.height,
      normBox.right * size.width,
      normBox.bottom * size.height,
    );

    if (isDashed) {
      final path = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)));
      _drawDashedPath(canvas, path, paint);
    } else {
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
    }
  }

  /// 점선 그리기
  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final segLen = draw ? 8.0 : 5.0;
        final end = (distance + segLen).clamp(0.0, metric.length);
        if (draw) {
          final segment = metric.extractPath(distance, end);
          canvas.drawPath(segment, paint);
        }
        distance = end;
        draw = !draw;
      }
    }
  }

  /// 외곽선을 가이드 위치로 이동
  List<Offset> _moveContour(
      List<Offset> contour, Offset fromCenter, Offset toCenter) {
    final dx = toCenter.dx - fromCenter.dx;
    final dy = toCenter.dy - fromCenter.dy;
    return contour
        .map((p) => Offset(
              (p.dx + dx).clamp(0.0, 1.0),
              (p.dy + dy).clamp(0.0, 1.0),
            ))
        .toList();
  }

  /// 박스를 가이드 위치로 이동
  Rect _moveBox(Rect box, Offset fromCenter, Offset toCenter) {
    final dx = toCenter.dx - fromCenter.dx;
    final dy = toCenter.dy - fromCenter.dy;
    return Rect.fromLTRB(
      (box.left + dx).clamp(0.0, 1.0),
      (box.top + dy).clamp(0.0, 1.0),
      (box.right + dx).clamp(0.0, 1.0),
      (box.bottom + dy).clamp(0.0, 1.0),
    );
  }

  /// 이동 화살표
  void _drawArrow(Canvas canvas, Size size, Offset from, Offset to) {
    final paint = Paint()
      ..color = const Color(0xFF00E676)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fromPx = Offset(from.dx * size.width, from.dy * size.height);
    final toPx = Offset(to.dx * size.width, to.dy * size.height);

    // 화살표 본체
    canvas.drawLine(fromPx, toPx, paint);

    // 화살표 머리
    final angle = (toPx - fromPx).direction;
    const arrowLen = 12.0;
    const arrowAngle = 0.5;

    final p1 = Offset(
      toPx.dx - arrowLen * cos(angle - arrowAngle),
      toPx.dy - arrowLen * sin(angle - arrowAngle),
    );
    final p2 = Offset(
      toPx.dx - arrowLen * cos(angle + arrowAngle),
      toPx.dy - arrowLen * sin(angle + arrowAngle),
    );

    canvas.drawLine(toPx, p1, paint);
    canvas.drawLine(toPx, p2, paint);
  }

  /// 수평선 (흰색 실선)
  void _drawHorizonLine(Canvas canvas, Size size, double y) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final py = y * size.height;
    canvas.drawLine(Offset(0, py), Offset(size.width, py), paint);
  }

  /// 수평선 가이드 (초록색 점선)
  void _drawHorizonGuide(Canvas canvas, Size size, double guideY) {
    final paint = Paint()
      ..color = const Color(0xFF00E676)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final py = guideY * size.height;

    // 점선
    double x = 0;
    bool draw = true;
    while (x < size.width) {
      if (draw) {
        canvas.drawLine(Offset(x, py), Offset((x + 8).clamp(0, size.width), py), paint);
      }
      x += draw ? 8 : 5;
      draw = !draw;
    }
  }

  double cos(double a) => a == 0 ? 1 : _cos(a);
  double sin(double a) => a == 0 ? 0 : _sin(a);
  double _cos(double a) => Offset.fromDirection(a).dx;
  double _sin(double a) => Offset.fromDirection(a).dy;

  @override
  bool shouldRepaint(covariant ContourGuidePainter old) {
    return old.objects != objects ||
        old.composition != composition ||
        old.sceneType != sceneType ||
        old.horizonY != horizonY;
  }
}
