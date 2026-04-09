import 'dart:ui';
import 'composition_scorer.dart';

/// YOLO 인식 결과로부터 씬 타입을 분류하고
/// 메인 피사체를 선택합니다.
class SceneClassifier {
  // 인물 관련 클래스 (COCO 기준)
  static const _personClasses = {'person'};

  // 풍경 대형 객체 (마스크가 전체의 50% 이상이면 풍경)
  static const _landscapeHint = {
    'bench', 'couch', 'bed', 'dining table',
    'tv', 'refrigerator',
  };

  // 작은 객체 (무시 대상)
  static const _smallObjects = {
    'fork', 'knife', 'spoon', 'toothbrush',
    'hair drier', 'scissors', 'remote',
  };

  /// 감지된 객체 목록으로부터 씬 타입 분류
  static SceneAnalysis analyze(List<DetectedObject> objects) {
    if (objects.isEmpty) {
      return SceneAnalysis(
        sceneType: SceneType.object,
        mainObject: null,
        filteredObjects: [],
      );
    }

    // 1) 작은 객체와 confidence 낮은 것 필터링
    final filtered = objects.where((o) {
      if (o.confidence < 0.4) return false;
      if (_smallObjects.contains(o.className) && o.areaRatio < 0.03) return false;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return SceneAnalysis(
        sceneType: SceneType.object,
        mainObject: null,
        filteredObjects: [],
      );
    }

    // 2) 씬 타입 결정
    final hasPerson = filtered.any((o) => _personClasses.contains(o.className));
    final totalArea = filtered.fold<double>(0, (sum, o) => sum + o.areaRatio);

    SceneType sceneType;
    if (hasPerson) {
      sceneType = SceneType.portrait;
    } else if (totalArea > 0.5) {
      sceneType = SceneType.landscape;
    } else {
      sceneType = SceneType.object;
    }

    // 3) 메인 피사체 선택 (가장 큰 면적 + confidence 가중치)
    filtered.sort((a, b) {
      final scoreA = a.areaRatio * 0.6 + a.confidence * 0.4;
      final scoreB = b.areaRatio * 0.6 + b.confidence * 0.4;
      return scoreB.compareTo(scoreA);
    });

    // 4) 최대 2개만 반환 (프롬프트 요구: 중요 사물 1~2개만 표시)
    final topObjects = filtered.take(2).toList();

    return SceneAnalysis(
      sceneType: sceneType,
      mainObject: topObjects.first,
      filteredObjects: topObjects,
    );
  }
}

/// 감지된 객체 정보
class DetectedObject {
  final String className;
  final int classIndex;
  final double confidence;
  final Rect normalizedBox; // 0~1
  final List<List<double>>? mask; // 80x80 probability
  final List<Offset>? contour; // 추출된 외곽선 (정규화)

  DetectedObject({
    required this.className,
    required this.classIndex,
    required this.confidence,
    required this.normalizedBox,
    this.mask,
    this.contour,
  });

  /// 화면 대비 면적 비율
  double get areaRatio =>
      normalizedBox.width * normalizedBox.height;

  /// 중심점 (정규화)
  Offset get center => Offset(
        normalizedBox.left + normalizedBox.width / 2,
        normalizedBox.top + normalizedBox.height / 2,
      );
}

/// 씬 분석 결과
class SceneAnalysis {
  final SceneType sceneType;
  final DetectedObject? mainObject;
  final List<DetectedObject> filteredObjects;

  SceneAnalysis({
    required this.sceneType,
    required this.mainObject,
    required this.filteredObjects,
  });

  String get sceneLabel {
    switch (sceneType) {
      case SceneType.portrait:
        return '인물';
      case SceneType.object:
        return '사물';
      case SceneType.landscape:
        return '풍경';
    }
  }
}
