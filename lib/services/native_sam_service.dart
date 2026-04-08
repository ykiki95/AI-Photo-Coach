import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

/// 네이티브 Subject Segmentation 호출 (MobileSAM 대체)
class NativeSamService {
  static const _channel = MethodChannel('ai_photo_coach/segmenter');

  /// 카메라 프레임 + bbox 목록 → 각 객체의 외곽선 포인트 반환
  Future<List<List<Offset>>> segmentObjects({
    required CameraImage image,
    required int rotation,
    required List<Rect> bboxes,
  }) async {
    if (bboxes.isEmpty) return [];

    try {
      final bytes = image.planes[0].bytes;

      final bboxMaps = bboxes.map((r) => {
        'left': r.left,
        'top': r.top,
        'width': r.width,
        'height': r.height,
      }).toList();

      final result = await _channel.invokeMethod('segmentObjects', {
        'bytes': bytes,
        'width': image.width,
        'height': image.height,
        'rotation': rotation,
        'bboxes': bboxMaps,
      });

      if (result == null) return [];

      // List<List<List<double>>> → List<List<Offset>>
      final List<List<Offset>> contours = [];
      for (final contourData in (result as List)) {
        final points = <Offset>[];
        for (final point in (contourData as List)) {
          final p = point as List;
          points.add(Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()));
        }
        contours.add(points);
      }

      return contours;
    } catch (e) {
      return List.generate(bboxes.length, (_) => <Offset>[]);
    }
  }
}