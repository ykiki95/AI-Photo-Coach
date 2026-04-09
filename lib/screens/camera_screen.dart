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
  // YOLO 컨트롤러
  final _controller = YOLOViewController();

  // 분석 상태
  List<DetectedObject> _detectedObjects = [];
  CompositionResult? _composition;
  SceneType _sceneType = SceneType.object;
  String _sceneLabel = '사물';
  double _score = 0;
  String _message = '사물을 비춰보세요';
  bool _shouldCapture = false;
  double? _horizonY;

  // 카메라 상태
  bool _isFrontCamera = false;

  // 진동 쿨다운
  DateTime _lastVibration = DateTime.now();

  // 외곽선 추출 프레임 스킵 (매 3프레임마다 한번)
  int _frameCount = 0;
  static const _contourEveryN = 3;
  // 이전 외곽선 캐시 (className → contour)
  final Map<String, List<Offset>> _contourCache = {};

  @override
  void initState() {
    super.initState();
    // 세로 고정
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    _controller.stop();
    super.dispose();
  }

  /// YOLO 인식 결과 처리 콜백
  void _onResult(List<YOLOResult> results) {
    if (!mounted) return;

    _frameCount++;
    final shouldExtractContour = (_frameCount % _contourEveryN == 0);

    // 1) YOLOResult → DetectedObject 변환 + 외곽선 추출
    final objects = <DetectedObject>[];
    for (final r in results) {
      List<Offset>? contour;

      if (shouldExtractContour && r.mask != null && r.mask!.isNotEmpty) {
        // 외곽선 새로 추출
        contour = MarchingSquares.extractContour(r.mask!, threshold: 0.5);
        if (contour.isNotEmpty) {
          contour = _mapContourToNormBox(contour, r.normalizedBox);
          // 캐시 업데이트
          _contourCache[r.className] = contour;
        }
      } else {
        // 캐시에서 이전 외곽선 사용
        contour = _contourCache[r.className];
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

    // 2) 씬 분류 + 메인 피사체 선택
    final analysis = SceneClassifier.analyze(objects);

    // 3) 구도 점수 계산
    CompositionResult? comp;
    double? horizonY;

    if (analysis.mainObject != null) {
      if (analysis.sceneType == SceneType.landscape) {
        // 풍경 모드: 가장 큰 객체의 상단을 수평선으로 간주
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

    // 4) 90점 이상 진동
    if (comp != null && comp.shouldCapture) {
      final now = DateTime.now();
      if (now.difference(_lastVibration).inMilliseconds > 2000) {
        HapticFeedback.mediumImpact();
        _lastVibration = now;
      }
    }

    // 5) 상태 업데이트
    setState(() {
      _detectedObjects = analysis.filteredObjects;
      _composition = comp;
      _sceneType = analysis.sceneType;
      _sceneLabel = analysis.sceneLabel;
      _score = comp?.score ?? 0;
      _message = comp?.message ?? '사물을 비춰보세요';
      _shouldCapture = comp?.shouldCapture ?? false;
      _horizonY = horizonY;
    });
  }

  /// mask 외곽선 좌표(0~1 내부)를 화면 normalizedBox 영역으로 매핑
  List<Offset> _mapContourToNormBox(List<Offset> contour, Rect normBox) {
    return contour.map((p) {
      return Offset(
        normBox.left + p.dx * normBox.width,
        normBox.top + p.dy * normBox.height,
      );
    }).toList();
  }

  /// 카메라 전환
  void _toggleCamera() {
    _controller.switchCamera();
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
  }

  /// 셔터 버튼 (현재는 진동 피드백만)
  void _onShutter() {
    HapticFeedback.heavyImpact();
    // TODO: 실제 캡처 구현
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📸 촬영! (구도 점수: ${_score.toInt()}점)'),
        duration: const Duration(seconds: 1),
        backgroundColor: _shouldCapture ? const Color(0xFF00C853) : Colors.grey[800],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // === 카메라 프리뷰 + YOLO (네이티브 오버레이 OFF) ===
            Positioned.fill(
              child: YOLOView(
                modelPath: 'yolo11n-seg_float32.tflite',
                task: YOLOTask.segment,
                controller: _controller,
                // ★ 핵심: 네이티브 오버레이 비활성화
                showOverlays: false,
                showNativeUI: false,
                // ★ 핵심: mask 데이터 수신 활성화
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
                // ★ 결과 콜백
                onResult: _onResult,
              ),
            ),

            // === 커스텀 외곽선 + 가이드 오버레이 ===
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

            // === 상단 HUD (씬 라벨 + 점수 + 메시지) ===
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 80,
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

            // === 하단 컨트롤 (셔터 + 카메라 토글) ===
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              height: 100,
              child: _buildBottomControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 빈 공간 (좌측 대칭)
          const SizedBox(width: 50),

          // === 셔터 버튼 ===
          GestureDetector(
            onTap: _onShutter,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _shouldCapture
                      ? const Color(0xFF00E676)
                      : Colors.white,
                  width: 4,
                ),
                color: _shouldCapture
                    ? const Color(0xFF00E676).withOpacity(0.3)
                    : Colors.transparent,
              ),
              child: Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _shouldCapture
                        ? const Color(0xFF00E676)
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // === 카메라 전환 버튼 ===
          GestureDetector(
            onTap: _toggleCamera,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: Icon(
                _isFrontCamera ? Icons.camera_rear : Icons.camera_front,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
