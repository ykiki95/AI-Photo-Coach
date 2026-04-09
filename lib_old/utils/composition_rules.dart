import 'dart:ui';
import 'dart:math';
import '../models/detected_object.dart';

/// 씬별 구도 규칙 엔진
class CompositionEngine {
  /// 감지된 객체들에 대해 구도 가이드 생성
  List<CompositionGuide> computeGuides(
      List<DetectedObjectInfo> objects,
      SceneType sceneType,
      Size frameSize,
      ) {
    final guides = <CompositionGuide>[];
    final topObjects = objects.take(3).toList();

    for (int i = 0; i < topObjects.length; i++) {
      final obj = topObjects[i];
      final guide = _computeGuideForObject(obj, sceneType, frameSize, i);
      guides.add(guide);
    }

    return guides;
  }

  /// 전체 구도 점수 계산 (0~100)
  int computeOverallScore(List<CompositionGuide> guides) {
    if (guides.isEmpty) return 50;
    final avg = guides.map((g) => g.matchScore).reduce((a, b) => a + b) / guides.length;
    return (avg * 100).round().clamp(0, 100);
  }

  /// 개별 객체의 구도 가이드 계산
  CompositionGuide _computeGuideForObject(
      DetectedObjectInfo obj,
      SceneType sceneType,
      Size frameSize,
      int index, // 0 = 주 피사체, 1~2 = 보조
      ) {
    final Offset idealCenter;
    final double idealScale;

    switch (sceneType) {
      case SceneType.portrait:
        idealCenter = _getPortraitIdeal(obj, frameSize, index);
        idealScale = 1.0;
        break;
      case SceneType.food:
        idealCenter = _getFoodIdeal(obj, frameSize, index);
        idealScale = 1.0;
        break;
      default:
        idealCenter = _getGeneralIdeal(obj, frameSize, index);
        idealScale = 1.0;
    }

    // 이상적 바운딩 박스
    final idealBounds = Rect.fromCenter(
      center: idealCenter,
      width: obj.boundingBox.width * idealScale,
      height: obj.boundingBox.height * idealScale,
    );

    // 현재 위치와 이상적 위치 간 거리로 일치율 계산
    final dist = (obj.center - idealCenter).distance;
    final maxDist = sqrt(frameSize.width * frameSize.width + frameSize.height * frameSize.height) / 2;
    final matchScore = (1.0 - (dist / maxDist)).clamp(0.0, 1.0);

    final needsMove = dist > frameSize.shortestSide * 0.05;

    String hint;
    if (matchScore > 0.9) {
      hint = '완벽한 위치!';
    } else if (matchScore > 0.7) {
      hint = '거의 다 됐어요!';
    } else {
      hint = _getDirectionHint(obj.center, idealCenter);
    }

    return CompositionGuide(
      object: obj,
      idealCenter: idealCenter,
      idealBounds: idealBounds,
      needsMove: needsMove,
      matchScore: matchScore,
      hint: hint,
    );
  }

  /// 인물 모드: 삼분법 기반 이상적 위치
  Offset _getPortraitIdeal(DetectedObjectInfo obj, Size frame, int index) {
    final cx = obj.center.dx / frame.width;

    if (index == 0) {
      // 주 피사체: 가장 가까운 삼분법 교차점
      final thirdX = (cx - 1 / 3).abs() < (cx - 2 / 3).abs() ? 1 / 3 : 2 / 3;
      // 눈높이 = 상단 1/3
      return Offset(thirdX * frame.width, frame.height / 3);
    } else {
      // 보조 피사체: 반대쪽 삼분법 점
      final thirdX = (cx - 1 / 3).abs() < (cx - 2 / 3).abs() ? 2 / 3 : 1 / 3;
      return Offset(thirdX * frame.width, frame.height * 2 / 3);
    }
  }

  /// 음식 모드: 중앙 배치
  Offset _getFoodIdeal(DetectedObjectInfo obj, Size frame, int index) {
    if (index == 0) {
      return Offset(frame.width / 2, frame.height * 0.45);
    } else if (index == 1) {
      return Offset(frame.width * 0.3, frame.height * 0.6);
    } else {
      return Offset(frame.width * 0.7, frame.height * 0.6);
    }
  }

  /// 일반 모드: 삼분법
  Offset _getGeneralIdeal(DetectedObjectInfo obj, Size frame, int index) {
    final cx = obj.center.dx / frame.width;
    final cy = obj.center.dy / frame.height;

    // 가장 가까운 삼분법 교차점
    final thirdX = [1.0 / 3, 0.5, 2.0 / 3].reduce(
            (best, v) => (cx - v).abs() < (cx - best).abs() ? v : best);
    final thirdY = [1.0 / 3, 0.5, 2.0 / 3].reduce(
            (best, v) => (cy - v).abs() < (cy - best).abs() ? v : best);

    return Offset(thirdX * frame.width, thirdY * frame.height);
  }

  /// 이동 방향 힌트
  String _getDirectionHint(Offset current, Offset ideal) {
    final dx = ideal.dx - current.dx;
    final dy = ideal.dy - current.dy;

    String h = dx.abs() > 20 ? (dx > 0 ? '오른쪽' : '왼쪽') : '';
    String v = dy.abs() > 20 ? (dy > 0 ? '아래' : '위') : '';

    if (h.isEmpty && v.isEmpty) return '좋은 위치!';
    return '$v$h으로 이동'.trim();
  }
}