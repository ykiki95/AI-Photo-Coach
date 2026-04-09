import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class Detection {
  final Rect rect;
  final String label;
  final double confidence;
  Detection(this.rect, this.label, this.confidence);
}

class YoloService {
  Interpreter? _interpreter;

  final List<String> _classes = [
    'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat', 'traffic light',
    'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird', 'cat', 'dog', 'horse', 'sheep', 'cow',
    'elephant', 'bear', 'zebra', 'giraffe', 'backpack', 'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee',
    'skis', 'snowboard', 'sports ball', 'kite', 'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket', 'bottle',
    'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple', 'sandwich', 'orange',
    'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 'chair', 'couch', 'potted plant', 'bed',
    'dining table', 'toilet', 'tv', 'laptop', 'mouse', 'remote', 'keyboard', 'cell phone', 'microwave', 'oven',
    'toaster', 'sink', 'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush'
  ];

  Future<void> loadModel() async {
    final options = InterpreterOptions();
    _interpreter = await Interpreter.fromAsset('assets/models/yolo11n_seg.tflite', options: options);
  }

  List<Detection> runInference(Float32List inputData, Size screenSize) {
    if (_interpreter == null) return [];

    var output0 = List.filled(1 * 116 * 8400, 0.0).reshape([1, 116, 8400]);
    var outputs = {0: output0};
    // 마스크(output1)는 화면 에러를 유발하므로 현재 단계에선 제외하여 안정성 극대화

    _interpreter!.runForMultipleInputs([inputData], outputs);

    List<Detection> rawDetections = [];

    for (int i = 0; i < 8400; i++) {
      double maxScore = 0;
      int classIndex = -1;

      for (int c = 4; c < 84; c++) {
        if (output0[0][c][i] > maxScore) {
          maxScore = output0[0][c][i];
          classIndex = c - 4;
        }
      }

      if (maxScore > 0.3) {
        double cx = output0[0][0][i] * screenSize.width / 640;
        double cy = output0[0][1][i] * screenSize.height / 640;
        double w = output0[0][2][i] * screenSize.width / 640;
        double h = output0[0][3][i] * screenSize.height / 640;

        Rect rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
        String label = (classIndex >= 0 && classIndex < _classes.length) ? _classes[classIndex] : 'object';
        rawDetections.add(Detection(rect, label, maxScore));
      }
    }

    return _applyNMS(rawDetections, 0.4);
  }

  List<Detection> _applyNMS(List<Detection> list, double iouThreshold) {
    List<Detection> result = [];
    list.sort((a, b) => b.confidence.compareTo(a.confidence));

    while (list.isNotEmpty) {
      Detection current = list.first;
      result.add(current);
      list.removeAt(0);

      list.removeWhere((det) {
        Rect intersect = current.rect.intersect(det.rect);
        if (intersect.width <= 0 || intersect.height <= 0) return false;
        double areaI = intersect.width * intersect.height;
        double areaA = current.rect.width * current.rect.height;
        double areaB = det.rect.width * det.rect.height;
        return (areaI / (areaA + areaB - areaI)) > iouThreshold;
      });
    }
    return result;
  }
}