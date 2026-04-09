import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/widgets/yolo_controller.dart';
import '../painters/contour_painter.dart';
import '../painters/hud_painter.dart';
import '../utils/marching_squares.dart';
import '../utils/composition_scorer.dart';
import '../utils/scene_classifier.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _controller = YOLOViewController();

  // 표시 상태
  List<DetectedObject> _detectedObjects = [];
  CompositionResult? _composition;
  SceneType _sceneType = SceneType.object;
  String _sceneLabel = '사물';
  double _score = 0;
  String _message = '사물을 비춰보세요';
  bool _shouldCapture = false;
  double? _horizonY;
  bool _isFrontCamera = false;
  DateTime _lastVibration = DateTime.now();

  // 깜박임 방지
  int _stableFrames = 0; // 연속 안정 프레임 수
  List<DetectedObject> _prevObjects = [];
  double _prevScore = -1;

  // 외곽선 캐시 (5프레임마다 갱신)
  int _frameCount = 0;
  final Map<String, List<Offset>> _contourCache = {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    _controller.stop();
    super.dispose();
  }

  /// ★ onStreamingData 방식 — raw Map에서 mask 직접 파싱
  void _onStreamingData(Map<String, dynamic> data) {
    if (!mounted) return;
    _frameCount++;

    final detectionsRaw = data['detections'] as List<dynamic>? ?? [];
    final objects = <DetectedObject>[];

    for (final det in detectionsRaw) {
      if (det is! Map) continue;

      final className = det['className'] as String? ?? '';
      final classIndex = (det['classIndex'] as num?)?.toInt() ?? 0;
      final confidence = (det['confidence'] as num?)?.toDouble() ?? 0;

      // normalizedBox 파싱
      final nb = det['normalizedBox'] as Map?;
      if (nb == null) continue;
      final normBox = Rect.fromLTRB(
        (nb['left'] as num?)?.toDouble() ?? 0,
        (nb['top'] as num?)?.toDouble() ?? 0,
        (nb['right'] as num?)?.toDouble() ?? 0,
        (nb['bottom'] as num?)?.toDouble() ?? 0,
      );

      // ★ mask 파싱 (160x160 List<List<double>>)
      List<List<double>>? mask;
      if (det['mask'] != null) {
        try {
          final rawMask = det['mask'] as List<dynamic>;
          mask = rawMask.map<List<double>>((row) {
            if (row is List) {
              return row.map<double>((v) => (v as num).toDouble()).toList();
            }
            return <double>[];
          }).toList();
        } catch (_) {}
      }

      // 외곽선 추출 (5프레임마다)
      List<Offset>? contour;
      final cacheKey = '${classIndex}_$className';

      if (_frameCount % 5 == 0 && mask != null && mask.isNotEmpty && mask[0].isNotEmpty) {
        contour = MarchingSquares.extractContour(mask, threshold: 0.5);
        if (contour.length >= 3) {
          contour = contour.map((p) => Offset(
            normBox.left + p.dx * normBox.width,
            normBox.top + p.dy * normBox.height,
          )).toList();
          _contourCache[cacheKey] = contour;
        } else {
          contour = _contourCache[cacheKey];
        }
      } else {
        contour = _contourCache[cacheKey];
      }

      objects.add(DetectedObject(
        className: className,
        classIndex: classIndex,
        confidence: confidence,
        normalizedBox: normBox,
        mask: mask,
        contour: (contour != null && contour.length >= 3) ? contour : null,
      ));
    }

    // 씬 분류 + 구도 점수
    final analysis = SceneClassifier.analyze(objects);
    CompositionResult? comp;
    double? horizonY;

    if (analysis.mainObject != null) {
      if (analysis.sceneType == SceneType.landscape) {
        horizonY = analysis.mainObject!.normalizedBox.top;
        comp = CompositionScorer.evaluateLandscape(horizonY: horizonY);
      } else {
        comp = CompositionScorer.evaluate(
          objectCenter: analysis.mainObject!.center,
          objectSize: analysis.mainObject!.areaRatio,
          sceneType: analysis.sceneType,
        );
      }
    }

    // 90점+ 진동
    if (comp != null && comp.shouldCapture) {
      final now = DateTime.now();
      if (now.difference(_lastVibration).inMilliseconds > 2000) {
        HapticFeedback.mediumImpact();
        _lastVibration = now;
      }
    }

    // ★ 깜박임 방지: 5% 이상 점수 변동 또는 객체 변경 시에만 UI 갱신
    final newScore = comp?.score ?? 0;
    final changed = _didChange(analysis.filteredObjects, newScore);

    if (changed) {
      _stableFrames = 0;
      setState(() {
        _detectedObjects = analysis.filteredObjects;
        _composition = comp;
        _sceneType = analysis.sceneType;
        _sceneLabel = analysis.sceneLabel;
        _score = newScore;
        _message = comp?.message ?? '사물을 비춰보세요';
        _shouldCapture = comp?.shouldCapture ?? false;
        _horizonY = horizonY;
      });
      _prevObjects = analysis.filteredObjects;
      _prevScore = newScore;
    } else {
      _stableFrames++;
    }
  }

  bool _didChange(List<DetectedObject> newObjs, double newScore) {
    if (newObjs.length != _prevObjects.length) return true;
    if ((_prevScore - newScore).abs() > 5.0) return true;
    for (int i = 0; i < newObjs.length; i++) {
      if (newObjs[i].className != _prevObjects[i].className) return true;
      if ((newObjs[i].center - _prevObjects[i].center).distance > 0.05) return true;
    }
    return false;
  }

  void _toggleCamera() {
    _controller.switchCamera();
    setState(() { _isFrontCamera = !_isFrontCamera; });
  }

  void _onShutter() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('📸 촬영! (구도 점수: ${_score.toInt()}점)'),
      duration: const Duration(seconds: 1),
      backgroundColor: _shouldCapture ? const Color(0xFF00C853) : Colors.grey[800],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ★ onStreamingData 사용 (onResult 대신)
            Positioned.fill(
              child: YOLOView(
                modelPath: 'yolo11n-seg_float32.tflite',
                task: YOLOTask.segment,
                controller: _controller,
                showOverlays: false,
                showNativeUI: false,
                streamingConfig: YOLOStreamingConfig.custom(
                  includeMasks: true,
                  includeProcessingTimeMs: true,
                  includeFps: true,
                  maxFPS: 12,
                ),
                confidenceThreshold: 0.4,
                iouThreshold: 0.45,
                useGpu: true,
                lensFacing: _isFrontCamera ? LensFacing.front : LensFacing.back,
                onStreamingData: _onStreamingData,
              ),
            ),

            // 외곽선 + 가이드
            Positioned.fill(
              child: RepaintBoundary(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: ContourGuidePainter(
                      objects: _detectedObjects,
                      composition: _composition,
                      sceneType: _sceneType,
                      horizonY: _horizonY,
                    ),
                  ),
                ),
              ),
            ),

            // 상단 HUD
            Positioned(
              top: 0, left: 0, right: 0, height: 80,
              child: RepaintBoundary(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: ScoreHudPainter(
                      score: _score,
                      sceneLabel: _sceneLabel,
                      message: _message,
                      shouldCapture: _shouldCapture,
                    ),
                  ),
                ),
              ),
            ),

            // 하단 컨트롤
            Positioned(
              bottom: 20, left: 0, right: 0, height: 100,
              child: _buildBottomControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const SizedBox(width: 50),
          GestureDetector(
            onTap: _onShutter,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _shouldCapture ? const Color(0xFF00E676) : Colors.white, width: 4),
                color: _shouldCapture ? const Color(0xFF00E676).withValues(alpha: 0.3) : Colors.transparent,
              ),
              child: Center(child: Container(width: 58, height: 58,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _shouldCapture ? const Color(0xFF00E676) : Colors.white))),
            ),
          ),
          GestureDetector(
            onTap: _toggleCamera,
            child: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.2)),
              child: Icon(_isFrontCamera ? Icons.camera_rear : Icons.camera_front, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}
