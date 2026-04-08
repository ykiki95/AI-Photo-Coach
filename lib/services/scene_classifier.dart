import '../models/detected_object.dart';

/// 감지된 객체들로 씬 타입 분류
class SceneClassifier {
  SceneInfo classify(List<DetectedObjectInfo> objects) {
    if (objects.isEmpty) return SceneInfo.general;

    bool hasPerson = false;
    bool hasFood = false;
    int objectCount = objects.length;

    for (final obj in objects) {
      final label = obj.label.toLowerCase();
      if (label.contains('사람') || label.contains('person')) {
        hasPerson = true;
      }
      if (label.contains('음식') || label.contains('food') ||
          label.contains('그릇') || label.contains('컵')) {
        hasFood = true;
      }
    }

    if (hasPerson) return SceneInfo.portrait;
    if (hasFood) return SceneInfo.food;
    return SceneInfo.general;
  }
}