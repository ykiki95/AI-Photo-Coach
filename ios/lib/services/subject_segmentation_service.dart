import 'dart:typed_data';
import 'dart:ui';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';

/// ML Kit Subject Segmentation 기반 외곽선 추출 서비스
///
/// MobileSAM ONNX 대비 장점:
/// - 모델 파일 불필요 (Google Play Services 자동 다운로드)
/// - 네이티브 코드 불필요 (순수 Dart)
/// - 사람, 동물, 사물 모두 인식
/// - 각 주체별 개별 마스크 제공
class SubjectSegmentationService {
  late final SubjectSegmenter _segmenter;
  bool _isInitialized = false;

  SubjectSegmentationService() {
    final options = SubjectSegmenterOptions(
      enableForegroundConfidenceMask: true,
      enableForegroundBitmap: false,
      enableMultipleSubjects: SubjectResultOptions(
        enableConfidenceMask: true,
        enableBitmap: false,
      ),
    );
    _segmenter = SubjectSegmenter(options: options);
    _isInitialized = true;
  }

  /// 카메라 프레임에서 각 주체의 외곽선 포인트 추출
  ///
  /// 반환: List<List<Offset>> - 기존 NativeSamService와 동일한 형식
  /// 각 리스트는 하나의 사물 외곽선 (이미지 좌표계)
  Future<List<List<Offset>>> segmentObjects({
    required CameraImage image,
    required int rotation,
    required List<Rect> bboxes,
  }) async {
    if (bboxes.isEmpty) return [];

    try {
      // CameraImage → InputImage
      final inputImage = _buildInputImage(image, rotation);
      if (inputImage == null) return List.generate(bboxes.length, (_) => <Offset>[]);

      // ML Kit Subject Segmentation 실행
      final result = await _segmenter.processImage(inputImage);
      final subjects = result.subjects;

      if (subjects.isEmpty) {
        return List.generate(bboxes.length, (_) => <Offset>[]);
      }

      // 이미지 크기 (회전 적용)
      final imgW = (rotation == 90 || rotation == 270)
          ? image.height.toDouble()
          : image.width.toDouble();
      final imgH = (rotation == 90 || rotation == 270)
          ? image.width.toDouble()
          : image.height.toDouble();

      // 각 bbox에 가장 가까운 subject 매칭 → 외곽선 추출
      final contours = <List<Offset>>[];

      for (final bbox in bboxes) {
        final bboxCenter = bbox.center;

        // 가장 가까운 subject 찾기
        Subject? bestSubject;
        double bestDist = double.infinity;

        for (final subject in subjects) {
          // subject의 confidence mask에서 중심 추정
          final mask = subject.confidenceMask;
          if (mask == null) continue;

          final maskW = subject.width;
          final maskH = subject.height;
          final startX = subject.startX;
          final startY = subject.startY;

          // subject 바운딩 박스 중심
          final subjectCenter = Offset(
            startX + maskW / 2.0,
            startY + maskH / 2.0,
          );

          final dist = (subjectCenter - bboxCenter).distance;
          if (dist < bestDist) {
            bestDist = dist;
            bestSubject = subject;
          }
        }

        if (bestSubject != null && bestSubject.confidenceMask != null) {
          final pts = _extractContourFromMask(
            bestSubject.confidenceMask!,
            bestSubject.width,
            bestSubject.height,
            bestSubject.startX,
            bestSubject.startY,
          );
          contours.add(pts);
        } else {
          contours.add(<Offset>[]);
        }
      }

      return contours;
    } catch (e) {
      return List.generate(bboxes.length, (_) => <Offset>[]);
    }
  }

  /// Confidence mask → 외곽선 포인트 추출
  ///
  /// 마스크의 경계(foreground ↔ background 전환점)를 따라
  /// 포인트를 추출합니다.
  List<Offset> _extractContourFromMask(
    ByteBuffer maskBuffer,
    int maskW,
    int maskH,
    int offsetX,
    int offsetY,
  ) {
    final mask = maskBuffer.asFloat32List();
    const threshold = 0.5;

    // Step 1: 이진 마스크 생성
    final binary = List.generate(maskH, (y) =>
      List.generate(maskW, (x) => mask[y * maskW + x] >= threshold),
    );

    // Step 2: 경계 포인트 추출 (4-connected boundary)
    final boundaryPoints = <Offset>[];

    for (int y = 1; y < maskH - 1; y++) {
      for (int x = 1; x < maskW - 1; x++) {
        if (!binary[y][x]) continue;

        // foreground 픽셀이고, 인접 픽셀 중 background가 있으면 경계
        if (!binary[y - 1][x] || !binary[y + 1][x] ||
            !binary[y][x - 1] || !binary[y][x + 1]) {
          boundaryPoints.add(Offset(
            (offsetX + x).toDouble(),
            (offsetY + y).toDouble(),
          ));
        }
      }
    }

    if (boundaryPoints.length < 10) return boundaryPoints;

    // Step 3: 경계 포인트를 순서대로 정렬 (중심 기준 각도 정렬)
    final sorted = _sortByAngle(boundaryPoints);

    // Step 4: 포인트 수 줄이기 (균등 샘플링)
    final targetCount = min(200, sorted.length);
    final step = sorted.length / targetCount;
    final sampled = <Offset>[];
    for (double i = 0; i < sorted.length; i += step) {
      sampled.add(sorted[i.floor()]);
    }

    return sampled;
  }

  /// 포인트를 중심 기준 각도로 정렬 (시계 방향)
  List<Offset> _sortByAngle(List<Offset> points) {
    if (points.isEmpty) return points;

    // 중심점 계산
    double cx = 0, cy = 0;
    for (final p in points) {
      cx += p.dx;
      cy += p.dy;
    }
    cx /= points.length;
    cy /= points.length;

    // 각도 기준 정렬
    final sorted = List<Offset>.from(points);
    sorted.sort((a, b) {
      final angleA = atan2(a.dy - cy, a.dx - cx);
      final angleB = atan2(b.dy - cy, b.dx - cx);
      return angleA.compareTo(angleB);
    });

    return sorted;
  }

  /// CameraImage → InputImage 변환
  InputImage? _buildInputImage(CameraImage image, int rotation) {
    try {
      final plane = image.planes[0];
      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _rotationFromDegrees(rotation),
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      );
      return InputImage.fromBytes(bytes: plane.bytes, metadata: metadata);
    } catch (e) {
      return null;
    }
  }

  InputImageRotation _rotationFromDegrees(int deg) {
    switch (deg) {
      case 90: return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default: return InputImageRotation.rotation0deg;
    }
  }

  void dispose() {
    _segmenter.close();
  }
}
