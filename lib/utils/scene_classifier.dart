import 'dart:ui';
import 'composition_scorer.dart';

class SceneClassifier {
  static const _personClasses = {'person'};
  static const _smallObjects = {
    'fork', 'knife', 'spoon', 'toothbrush', 'hair drier', 'scissors', 'remote',
  };
  static const _knownObjects = {
    'bottle', 'cup', 'laptop', 'tv', 'refrigerator', 'couch', 'bed',
    'dining table', 'chair', 'toilet', 'sink', 'microwave', 'oven',
    'cell phone', 'book', 'vase', 'backpack', 'suitcase', 'mouse',
    'keyboard', 'clock', 'potted plant',
  };

  static SceneAnalysis analyze(List<DetectedObject> objects) {
    if (objects.isEmpty) {
      return SceneAnalysis(sceneType: SceneType.object, mainObject: null, filteredObjects: []);
    }

    final filtered = objects.where((o) {
      if (o.confidence < 0.4) return false;
      if (_smallObjects.contains(o.className) && o.areaRatio < 0.03) return false;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return SceneAnalysis(sceneType: SceneType.object, mainObject: null, filteredObjects: []);
    }

    final hasPerson = filtered.any((o) => _personClasses.contains(o.className));
    final allKnown = filtered.every((o) =>
        _personClasses.contains(o.className) ||
        _knownObjects.contains(o.className) ||
        _smallObjects.contains(o.className));

    SceneType sceneType;
    if (hasPerson) {
      sceneType = SceneType.portrait;
    } else if (!allKnown && filtered.length <= 1 && filtered.first.areaRatio > 0.6) {
      sceneType = SceneType.landscape;
    } else {
      sceneType = SceneType.object;
    }

    filtered.sort((a, b) {
      final scoreA = a.areaRatio * 0.6 + a.confidence * 0.4;
      final scoreB = b.areaRatio * 0.6 + b.confidence * 0.4;
      return scoreB.compareTo(scoreA);
    });

    return SceneAnalysis(
      sceneType: sceneType,
      mainObject: filtered.first,
      filteredObjects: filtered.take(2).toList(),
    );
  }
}

class DetectedObject {
  final String className;
  final int classIndex;
  final double confidence;
  final Rect normalizedBox;
  final List<List<double>>? mask;
  final List<Offset>? contour;

  DetectedObject({
    required this.className,
    required this.classIndex,
    required this.confidence,
    required this.normalizedBox,
    this.mask,
    this.contour,
  });

  double get areaRatio => normalizedBox.width * normalizedBox.height;
  Offset get center => Offset(
    normalizedBox.left + normalizedBox.width / 2,
    normalizedBox.top + normalizedBox.height / 2,
  );
}

class SceneAnalysis {
  final SceneType sceneType;
  final DetectedObject? mainObject;
  final List<DetectedObject> filteredObjects;

  SceneAnalysis({required this.sceneType, required this.mainObject, required this.filteredObjects});

  String get sceneLabel {
    switch (sceneType) {
      case SceneType.portrait: return '인물';
      case SceneType.object: return '사물';
      case SceneType.landscape: return '풍경';
    }
  }
}
