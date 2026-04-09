import 'dart:ui';
import 'dart:math' as math;

enum SceneType { portrait, object, landscape }

class CompositionResult {
  final double score;
  final Offset guidePosition;
  final String message;
  final bool shouldCapture;
  final String moveDirection;
  const CompositionResult({required this.score, required this.guidePosition, required this.message, required this.shouldCapture, required this.moveDirection});
}

class CompositionScorer {
  static const _thirdPoints = [Offset(1/3, 1/3), Offset(2/3, 1/3), Offset(1/3, 2/3), Offset(2/3, 2/3)];

  static CompositionResult evaluate({required Offset objectCenter, required double objectSize, required SceneType sceneType}) {
    double minDist = double.infinity;
    Offset bestPoint = _thirdPoints[0];
    for (final tp in _thirdPoints) {
      final d = (objectCenter - tp).distance;
      if (d < minDist) { minDist = d; bestPoint = tp; }
    }
    final distScore = math.max(0.0, (1.0 - (minDist / 0.47))) * 100;
    double sizeScore = sceneType == SceneType.portrait
        ? _gauss(objectSize, 0.45, 0.15) * 100
        : sceneType == SceneType.landscape ? 80 : _gauss(objectSize, 0.25, 0.12) * 100;
    final score = (distScore * 0.7 + sizeScore * 0.3).clamp(0.0, 100.0);
    final moveDir = _moveDir(objectCenter, bestPoint, objectSize, sceneType);
    return CompositionResult(
      score: score, guidePosition: bestPoint,
      message: score >= 90 ? '지금 촬영하세요!' : score >= 70 ? '거의 완벽해요!' : _moveMsg(moveDir),
      shouldCapture: score >= 90, moveDirection: moveDir,
    );
  }

  static CompositionResult evaluateLandscape({required double horizonY}) {
    final dU = (horizonY - 1/3).abs(), dL = (horizonY - 2/3).abs();
    final bestY = dU < dL ? 1.0/3 : 2.0/3;
    final score = (math.max(0.0, (1.0 - (math.min(dU, dL) / 0.33))) * 100).clamp(0.0, 100.0);
    final dir = score >= 90 ? 'none' : (horizonY < bestY ? 'down' : 'up');
    return CompositionResult(
      score: score, guidePosition: Offset(0.5, bestY),
      message: score >= 90 ? '지금 촬영하세요!' : '수평선을 ${dir == "up" ? "위" : "아래"}로 맞추세요',
      shouldCapture: score >= 90, moveDirection: dir,
    );
  }

  static double _gauss(double x, double m, double s) => math.exp(-math.pow(x - m, 2) / (2 * s * s));
  static String _moveDir(Offset cur, Offset tgt, double size, SceneType st) {
    if ((cur - tgt).distance < 0.05) {
      if (st == SceneType.portrait) { if (size < 0.25) return 'closer'; if (size > 0.65) return 'farther'; }
      else { if (size < 0.10) return 'closer'; if (size > 0.50) return 'farther'; }
      return 'none';
    }
    final dx = tgt.dx - cur.dx, dy = tgt.dy - cur.dy;
    return dx.abs() > dy.abs() ? (dx > 0 ? 'right' : 'left') : (dy > 0 ? 'down' : 'up');
  }
  static String _moveMsg(String d) => switch(d) { 'left'=>'← 왼쪽으로 이동', 'right'=>'오른쪽으로 이동 →', 'up'=>'↑ 위로 이동', 'down'=>'아래로 이동 ↓', 'closer'=>'더 가까이 다가가세요', 'farther'=>'좀 더 멀리 떨어지세요', _=>'좋은 구도입니다!' };
}
