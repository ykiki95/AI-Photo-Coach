import 'dart:ui';

/// 감지된 객체 정보
class DetectedObjectInfo {
  final String label;
  final double confidence;
  final Rect boundingBox;
  final List<Offset>? contourPoints; // 세그멘테이션 외곽선 (있으면)
  final bool isSegmented; // 세그멘테이션 마스크 기반 여부

  DetectedObjectInfo({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    this.contourPoints,
    this.isSegmented = false,
  });

  Offset get center => boundingBox.center;
  double get area => boundingBox.width * boundingBox.height;
}

/// 구도 가이드 정보
class CompositionGuide {
  final DetectedObjectInfo object;
  final Offset idealCenter;    // 이상적 위치 중심
  final Rect idealBounds;      // 이상적 위치 영역
  final bool needsMove;        // 이동 필요 여부
  final double matchScore;     // 일치율 (0~1)
  final String hint;           // 가이드 메시지

  CompositionGuide({
    required this.object,
    required this.idealCenter,
    required this.idealBounds,
    required this.needsMove,
    required this.matchScore,
    required this.hint,
  });
}

/// 씬 타입
enum SceneType {
  portrait,   // 인물
  food,       // 음식
  landscape,  // 풍경
  general,    // 일반
}

/// 씬 정보
class SceneInfo {
  final SceneType type;
  final String label;
  final String icon;

  const SceneInfo({
    required this.type,
    required this.label,
    required this.icon,
  });

  static const portrait = SceneInfo(type: SceneType.portrait, label: '인물', icon: '👤');
  static const food = SceneInfo(type: SceneType.food, label: '음식', icon: '🍕');
  static const landscape = SceneInfo(type: SceneType.landscape, label: '풍경', icon: '🏙');
  static const general = SceneInfo(type: SceneType.general, label: '일반', icon: '📷');
}