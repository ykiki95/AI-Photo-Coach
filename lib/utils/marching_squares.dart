import 'dart:ui';

/// mask (NxN, 80x80 또는 160x160) → 외곽선 좌표 (0~1 정규화)
class MarchingSquares {
  static List<Offset> extractContour(List<List<double>> mask, {double threshold = 0.5}) {
    if (mask.isEmpty || mask[0].isEmpty) return [];
    final h = mask.length;
    final w = mask[0].length;

    // 경계 픽셀 수집
    final pts = <Offset>[];
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (mask[y][x] < threshold) continue;
        if (_isBorder(mask, x, y, w, h, threshold)) {
          pts.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }
    if (pts.length < 3) return [];

    // 순서 정렬 + 간소화
    final ordered = _order(pts);
    final simplified = _simplify(ordered, 1.0);

    // 정규화
    return simplified.map((p) => Offset(p.dx / w, p.dy / h)).toList();
  }

  static bool _isBorder(List<List<double>> mask, int x, int y, int w, int h, double t) {
    if (x == 0 || y == 0 || x == w - 1 || y == h - 1) return true;
    return mask[y-1][x] < t || mask[y+1][x] < t || mask[y][x-1] < t || mask[y][x+1] < t;
  }

  static List<Offset> _order(List<Offset> pts) {
    if (pts.length <= 2) return pts;
    final result = <Offset>[];
    final remaining = List<Offset>.from(pts);
    // 시작: 최상단-좌측
    remaining.sort((a, b) { final c = a.dy.compareTo(b.dy); return c != 0 ? c : a.dx.compareTo(b.dx); });
    var cur = remaining.removeAt(0);
    result.add(cur);
    while (remaining.isNotEmpty) {
      double minD = double.infinity; int minI = 0;
      for (int i = 0; i < remaining.length; i++) {
        final d = (remaining[i] - cur).distanceSquared;
        if (d < minD) { minD = d; minI = i; }
      }
      if (minD > 16.0 && result.length > 10) break; // 4px 이상 떨어지면 끊기
      cur = remaining.removeAt(minI);
      result.add(cur);
    }
    return result;
  }

  static List<Offset> _simplify(List<Offset> pts, double eps) {
    if (pts.length <= 3) return pts;
    double maxD = 0; int maxI = 0;
    final f = pts.first, l = pts.last;
    for (int i = 1; i < pts.length - 1; i++) {
      final d = _perpDist(pts[i], f, l);
      if (d > maxD) { maxD = d; maxI = i; }
    }
    if (maxD > eps) {
      final left = _simplify(pts.sublist(0, maxI + 1), eps);
      final right = _simplify(pts.sublist(maxI), eps);
      return [...left.sublist(0, left.length - 1), ...right];
    }
    return [f, l];
  }

  static double _perpDist(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return (p - a).distance;
    final t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq;
    return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
  }
}
