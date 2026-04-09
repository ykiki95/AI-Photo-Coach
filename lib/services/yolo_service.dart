import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class YoloService {
  Interpreter? _interpreter;

  // 모델 로드: S24 Ultra의 NPU(NNAPI) 가속 활용
  Future<void> loadModel() async {
    final options = InterpreterOptions()..useNnapiDelegate();
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/yolo11n_seg.tflite', options: options);
      print("YOLO 모델 로드 성공");
    } catch (e) {
      print("모델 로드 실패: $e");
    }
  }

  // 추론 실행 및 외곽선 좌표 반환
  List<List<Offset>> runInference(List<double> inputData, Size screenSize) {
    if (_interpreter == null) return [];

    // YOLO11n-seg 출력 텐서 구조 설정
    var output0 = List.filled(1 * 116 * 8400, 0.0).reshape([1, 116, 8400]);
    var output1 = List.filled(1 * 32 * 160 * 160, 0.0).reshape([1, 32, 160, 160]);
    var outputs = {0: output0, 1: output1};

    _interpreter!.runForMultipleInputs([inputData], outputs);

    // TODO: 후처리(Post-processing) 로직을 통해 상위 3개 객체의 외곽선 좌표 리스트 생성
    // 현재는 구조 연결을 위한 빈 리스트 반환 상태
    return [];
  }
}