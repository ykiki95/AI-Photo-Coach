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

  // 현재 표시 중인 상태
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

  // 깜박임 방지: 이전 프레임 결과 보관 + 변경 감지
  List<DetectedObject> _prevObjects = [];
  double _prevScore = 0;
  String _prevSceneLabel = '';

  // 외곽선 추출 프레임 스킵 (매 3프레임마다)
  int _frameCount = 0;
  static const _contourEveryN = 3;
  final Map<String, List<Offset>> _contourCache = {};

  // mask 디버그 카운터
  int _maskReceivedCount = 0;
  int _maskNullCount = 0;

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

  void _onResult(List<YOLOResult> results) {
    if (!mounted) return;

    _frameCount++;
    final shouldExtractContour = (_frameCount % _contourEveryN == 0);

    final objects = <DetectedObject>[];
    for (final r in results) {
      // mask 디버그 (처음 30프레임만)
      if (_frameCount <= 30) {
        if (r.mask != null && r.mask!.isNotEmpty) {
          _maskReceivedCount++;
          if (_frameCount == 30) {
            debugPrint('📊 mask 수신 통계: received=$_maskReceivedCount, null=$_maskNullCount (30프레임)');
            debugPrint('📊 mask 크기: ${r.mask!.length}x${r.mask!.first.length}');
          }
        } else {
          _maskNullCount++;
        }
      }

      List<Offset>? contour;

      if (shouldExtractContour && r.mask != null && r.mask!.isNotEmpty) {
        contour = MarchingSquares.extractContour(r.mask!, threshold: 0.5);
        if (contour.isNotEmpty) {
          contour = _mapContourToNormBox(contour, r.normalizedBox);
          _contourCache['${r.classIndex}_${r.className}'] = contour;
        }
      } else {
        contour = _contourCache['${r.classIndex}_${r.className}'];
      }

      objects.add(DetectedObject(
        className: r.className,
        classIndex: r.classIndex,
        confidence: r.confidence,
        normalizedBox: r.normalizedBox,
        mask: r.mask,
        contour: (contour != null && contour.length >= 3) ? contour : null,
      ));
    }

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

    if (comp != null && comp.shouldCapture) {
      final now = DateTime.now();
      if (now.difference(_lastVibration).inMilliseconds > 2000) {
        HapticFeedback.mediumImpact();
        _lastVibration = now;
      }
    }

    // 깜박임 방지: 의미 있는 변화가 있을 때만 setState
    final newScore = comp?.score ?? 0;
    final newLabel = analysis.sceneLabel;
    final objectsChanged = _didObjectsChange(analysis.filteredObjects, _prevObjects);
    final scoreChanged = (newScore - _prevScore).abs() > 2.0;
    final labelChanged = newLabel != _prevSceneLabel;

    if (objectsChanged || scoreChanged || labelChanged) {
      _prevObjects = analysis.filteredObjects;
      _prevScore = newScore;
      _prevSceneLabel = newLabel;

      setState(() {
        _detectedObjects = analysis.filteredObjects;
        _composition = comp;
        _sceneType = analysis.sceneType;
        _sceneLabel = newLabel;
        _score = newScore;
        _message = comp?.message ?? '사물을 비춰보세요';
        _shouldCapture = comp?.shouldCapture ?? false;
        _horizonY = horizonY;
      });
    }
  }

  /// 객체 목록이 의미 있게 변경되었는지 확인
  bool _didObjectsChange(List<DetectedObject> a, List<DetectedObject> b) {
    if (a.length != b.length) return true;
    for (int i = 0; i < a.length; i++) {
      if (a[i].className != b[i].className) return true;
      // 중심점이 3% 이상 이동했으면 변경
      if ((a[i].center - b[i].center).distance > 0.03) return true;
    }
    return false;
  }

  List<Offset> _mapContourToNormBox(List<Offset> contour, Rect normBox) {
    return contour.map((p) => Offset(
      normBox.left + p.dx * normBox.width,
      normBox.top + p.dy * normBox.height,
    )).toList();
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
                  maxFPS: 15,
                ),
                confidenceThreshold: 0.4,
                iouThreshold: 0.45,
                useGpu: true,
                lensFacing: _isFrontCamera ? LensFacing.front : LensFacing.back,
                onResult: _onResult,
              ),
            ),

            Positioned.fill(
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

            Positioned(
              top: 0, left: 0, right: 0, height: 80,
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
              child: Center(
                child: Container(width: 58, height: 58,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _shouldCapture ? const Color(0xFF00E676) : Colors.white),
                ),
              ),
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
