import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../models/detected_object.dart';
import '../services/subject_segmentation_service.dart';
import '../services/object_detector_service.dart';
import '../services/scene_classifier.dart';
import '../services/contour_extractor.dart';
import '../utils/composition_rules.dart';
import '../painters/contour_painter.dart';
import '../painters/guide_painter.dart';
import 'result_screen.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _cam;
  late List<CameraDescription> _cameras;

  // 서비스
  final _detector = ObjectDetectorService();
  final _segService = SubjectSegmentationService();  // ★ ML Kit Subject Segmentation
  final _sceneClassifier = SceneClassifier();
  final _compositionEngine = CompositionEngine();

  // 상태
  bool _ready = false;
  bool _busy = false;
  int _frame = 0;

  List<DetectedObjectInfo> _objects = [];
  List<List<Offset>> _contours = [];
  List<List<Offset>> _smoothContours = [];
  List<CompositionGuide> _guides = [];
  SceneInfo _scene = SceneInfo.general;
  int _score = 50;
  String _msg = '피사체를 비춰주세요';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    _cam = CameraController(
      _cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _cam!.initialize();
    await _cam!.startImageStream(_onFrame);
    if (mounted) setState(() => _ready = true);
  }

  void _onFrame(CameraImage image) async {
    _frame++;
    if (_frame % 8 != 0 || _busy) return;
    _busy = true;

    try {
      final rotation = _cameras[0].sensorOrientation;
      final imgSize = Size(image.width.toDouble(), image.height.toDouble());

      // ① Detector: 상위 2개 객체
      final allObjects = await _detector.detectObjects(
        image,
        _rotationFromDegrees(rotation),
        imgSize,
      );
      final objects = allObjects.take(2).toList();

      if (objects.isEmpty) {
        if (mounted) {
          setState(() {
            _objects = []; _contours = []; _smoothContours = [];
            _guides = []; _score = 50; _msg = '피사체를 비춰주세요';
          });
        }
        return;
      }

      // ② ML Kit Subject Segmentation → 외곽선
      final bboxes = objects.map((o) => o.boundingBox).toList();
      final rawContours = await _segService.segmentObjects(
        image: image,
        rotation: rotation,
        bboxes: bboxes,
      );

      // ③ Chaikin 스무딩
      final smoothed = rawContours.map((pts) {
        if (pts.length < 8) return pts;
        return ContourSmoother.chaikinSmooth(pts, 3);
      }).toList();

      // ④ 씬 분류 + 구도 가이드
      final scene = _sceneClassifier.classify(objects);

      final rotatedSize = (rotation == 90 || rotation == 270)
          ? Size(imgSize.height, imgSize.width)
          : imgSize;

      final guides = _compositionEngine.computeGuides(objects, scene.type, rotatedSize);
      final score = _compositionEngine.computeOverallScore(guides);

      String msg;
      if (score >= 90) {
        msg = '지금 촬영하세요! 📸';
        HapticFeedback.mediumImpact();
      } else if (score >= 70) {
        msg = '거의 다 됐어요!';
      } else {
        msg = '구도를 맞춰주세요';
      }

      if (mounted) {
        setState(() {
          _objects = objects;
          _contours = rawContours;
          _smoothContours = smoothed;
          _scene = scene;
          _guides = guides;
          _score = score;
          _msg = msg;
        });
      }
    } catch (e) {
      // skip frame
    } finally {
      _busy = false;
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

  Future<void> _takePicture() async {
    if (_cam == null) return;
    try {
      await _cam!.stopImageStream();
      final file = await _cam!.takePicture();
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ResultScreen(imagePath: file.path, score: _score, scene: _scene),
        )).then((_) => _cam?.startImageStream(_onFrame));
      }
    } catch (e) {
      _cam?.startImageStream(_onFrame);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    _detector.dispose();
    _segService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final preview = _cam?.value.previewSize;
    final imgSize = preview != null
        ? Size(preview.height, preview.width)
        : screen;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 카메라
          if (_ready && _cam != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: preview!.height,
                  height: preview.width,
                  child: CameraPreview(_cam!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // ★ 흰색 외곽선 (사물 형태)
          if (_smoothContours.isNotEmpty)
            CustomPaint(
              size: screen,
              painter: ContourPainter(
                objects: _objects,
                contours: _smoothContours,
                imageSize: imgSize,
                widgetSize: screen,
              ),
            ),

          // ★ 초록색 구도 가이드 (사물 형태)
          if (_guides.isNotEmpty)
            CustomPaint(
              size: screen,
              painter: GuidePainter(
                guides: _guides,
                contours: _smoothContours,
                imageSize: imgSize,
                widgetSize: screen,
              ),
            ),

          // 상단 UI
          _buildTopBar(screen),

          // 셔터 버튼
          _buildShutter(screen),
        ],
      ),
    );
  }

  Widget _buildTopBar(Size screen) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 14, right: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
            child: Text('${_scene.icon} ${_scene.label}',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Row(children: [
            SizedBox(
              width: 42, height: 42,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                  value: _score / 100, strokeWidth: 3,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation(
                      _score >= 90 ? const Color(0xFF22C55E) :
                      _score >= 70 ? const Color(0xFFEAB308) : const Color(0xFFEF4444)),
                ),
                Text('$_score', style: TextStyle(
                    color: _score >= 90 ? const Color(0xFF22C55E) : Colors.white,
                    fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(width: 8),
            Text(_msg, style: TextStyle(
                color: _score >= 90 ? const Color(0xFF22C55E) : Colors.white70,
                fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }

  Widget _buildShutter(Size screen) {
    final good = _score >= 90;
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 24,
      left: 0, right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _takePicture,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: good ? const Color(0xFF22C55E) : Colors.white, width: 4),
              boxShadow: good ? [BoxShadow(color: const Color(0xFF22C55E).withOpacity(0.4), blurRadius: 16)] : null,
            ),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle, color: good ? const Color(0xFF22C55E) : Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
