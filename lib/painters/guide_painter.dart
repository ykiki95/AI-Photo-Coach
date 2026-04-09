import 'package:flutter/material.dart';

class GuidePainter extends CustomPainter {
  final List<List<Offset>> currentContours;
  final List<Path> expertGuides;
  final double matchScore;

  GuidePainter({
    required this.currentContours,
    required this.expertGuides,
    this.matchScore = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 현재 사물 외곽선 스타일 (흰색 실선)
    final whitePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // 2. 전문가 추천 가이드 스타일 (초록색 실선)
    final greenPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // 사물 외곽선 그리기
    for (var points in currentContours) {
      if (points.isNotEmpty) {
        final path = Path()..addPolygon(points, true);
        canvas.drawPath(path, whitePaint);
      }
    }

    // 전문가 가이드 그리기
    for (var path in expertGuides) {
      canvas.drawPath(path, greenPaint);
    }

    // 점수가 높을 때 텍스트 표시
    if (matchScore > 85) {
      _drawBestShotUI(canvas, size);
    }
  }

  void _drawBestShotUI(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: "BEST SHOT",
        style: TextStyle(color: Colors.greenAccent, fontSize: 40, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(size.width / 2 - textPainter.width / 2, size.height * 0.7));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}