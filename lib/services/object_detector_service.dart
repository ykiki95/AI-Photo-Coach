import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import '../models/detected_object.dart';

/// ML Kit 객체 감지 서비스
class ObjectDetectorService {
  late final ObjectDetector _detector;
  bool _isProcessing = false;

  ObjectDetectorService() {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    );
    _detector = ObjectDetector(options: options);
  }

  /// 카메라 이미지에서 객체 감지 → 상위 2~3개 반환
  Future<List<DetectedObjectInfo>> detectObjects(
      CameraImage image,
      InputImageRotation rotation,
      Size frameSize,
      ) async {
    if (_isProcessing) return [];
    _isProcessing = true;

    try {
      final inputImage = _buildInputImage(image, rotation);
      if (inputImage == null) return [];

      final objects = await _detector.processImage(inputImage);

      final results = objects
          .where((obj) => obj.boundingBox.width > 30 && obj.boundingBox.height > 30)
          .map((obj) {
        // 라벨 추출
        String label = '물체';
        double confidence = 0.5;
        if (obj.labels.isNotEmpty) {
          final topLabel = obj.labels.reduce(
                (a, b) => a.confidence > b.confidence ? a : b,
          );
          label = _translateLabel(topLabel.text);
          confidence = topLabel.confidence;
        }

        return DetectedObjectInfo(
          label: label,
          confidence: confidence,
          boundingBox: obj.boundingBox,
          isSegmented: false,
        );
      }).toList();

      // 면적 × 신뢰도로 정렬, 상위 3개
      results.sort((a, b) =>
          (b.area * b.confidence).compareTo(a.area * a.confidence));

      return results.take(3).toList();
    } catch (e) {
      return [];
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image, InputImageRotation rotation) {
    try {
      final plane = image.planes[0];
      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      );
      return InputImage.fromBytes(bytes: plane.bytes, metadata: metadata);
    } catch (e) {
      return null;
    }
  }

  /// 영문 라벨 → 한글 변환
  String _translateLabel(String label) {
    const map = {
      'Fashion good': '의류',
      'Food': '음식',
      'Home good': '생활용품',
      'Place': '장소',
      'Plant': '식물',
      'Person': '사람',
    };
    return map[label] ?? label;
  }

  void dispose() {
    _detector.close();
  }
}