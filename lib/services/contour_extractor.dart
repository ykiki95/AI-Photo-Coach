import 'dart:ui';

/// Chaikin 스무딩 (네이티브에서 DP 단순화된 포인트를 부드럽게)
class ContourSmoother {
  /// Chaikin subdivision 스무딩
  static List<Offset> chaikinSmooth(List<Offset> points, int iterations) {
    if (points.length < 4) return points;
    var current = points;
    for (int i = 0; i < iterations; i++) {
      final next = <Offset>[];
      for (int j = 0; j < current.length; j++) {
        final a = current[j];
        final b = current[(j + 1) % current.length];
        next.add(Offset(a.dx * 0.75 + b.dx * 0.25, a.dy * 0.75 + b.dy * 0.25));
        next.add(Offset(a.dx * 0.25 + b.dx * 0.75, a.dy * 0.25 + b.dy * 0.75));
      }
      current = next;
    }
    return current;
  }

  /// 외곽선 이동 (구도 가이드용)
  static List<Offset> translateContour(List<Offset> points, double dx, double dy) {
    return points.map((p) => Offset(p.dx + dx, p.dy + dy)).toList();
  }

  /// 외곽선을 위젯 좌표로 변환
  static List<Offset> toWidgetCoords(
      List<Offset> points, Size imageSize, Size widgetSize,
      ) {
    final sx = widgetSize.width / imageSize.width;
    final sy = widgetSize.height / imageSize.height;
    return points.map((p) => Offset(p.dx * sx, p.dy * sy)).toList();
  }
}