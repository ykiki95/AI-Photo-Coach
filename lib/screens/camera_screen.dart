import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/yolo_service.dart';
import '../painters/guide_painter.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  YoloService _yoloService = YoloService();
  List<List<Offset>> _contours = [];
  double _score = 0.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _yoloService.loadModel();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    _controller = CameraController(cameras[0], ResolutionPreset.high);
    await _controller!.initialize();

    // 실시간 이미지 스트림 시작
    _controller!.startImageStream((image) {
      // TODO: 이미지를 YOLO 입력 형식으로 변환 후 추론 실행
      // final results = _yoloService.runInference(inputData, MediaQuery.of(context).size);
      // setState(() { _contours = results; });
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container();
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_controller!), // 카메라 화면
          CustomPaint(                // AI 가이드 레이어
            size: Size.infinite,
            painter: GuidePainter(
              currentContours: _contours,
              expertGuides: [], // 전문가 가이드 Path 데이터 전달
              matchScore: _score,
            ),
          ),
        ],
      ),
    );
  }
}