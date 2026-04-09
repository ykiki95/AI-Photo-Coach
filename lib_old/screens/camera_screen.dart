import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  List<YOLOResult> _mainObjects = [];
  int _score = 50;
  String _msg = '피사체를 비춰주세요';
  String _sceneLabel = '일반';
  String _sceneIcon = '📷';
  Rect? _guideBox;
  String _guideMsg = '';
  bool _isFrontCamera = false;
  int _rebuildKey = 0;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final good = _score >= 90;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ① YOLOView (카메라 + 인식) — 전체 화면
          Positioned.fill(
            child: YOLOView(
              key: ValueKey('yolo_$_rebuildKey'),
              modelPath: 'yolo11n-seg_float32',
              task: YOLOTask.segment,
              onResult: _onYoloResult,
            ),
          ),

          // ② 커스텀 오버레이 (흰색 bbox + 초록색 가이드)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _PhotoCoachPainter(
                  mainObjects: _mainObjects,
                  guideBox: _guideBox,
                  guideMsg: _guideMsg,
                  screenSize: screen,
                  score: _score,
                ),
              ),
            ),
          ),

          // ③ 상단 UI (반투명 배경으로 가독성 확보)
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 14, right: 14, bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 씬 라벨
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                    child: Text('$_sceneIcon $_sceneLabel',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  // 점수 + 메시지
                  Row(children: [
                    SizedBox(
                      width: 44, height: 44,
                      child: Stack(alignment: Alignment.center, children: [
                        CircularProgressIndicator(
                          value: _score / 100, strokeWidth: 3.5,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation(
                              good ? const Color(0xFF22C55E) :
                              _score >= 70 ? const Color(0xFFEAB308) : const Color(0xFFEF4444)),
                        ),
                        Text('$_score', style: TextStyle(
                            color: good ? const Color(0xFF22C55E) : Colors.white,
                            fontSize: 15, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text(_msg, style: TextStyle(
                        color: good ? const Color(0xFF22C55E) : Colors.white,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
          ),

          // ④ 하단: 셔터 + 카메라 토글 (반투명 배경)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 60),
                  // 셔터 버튼
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('점수 $_score로 촬영! (데모)'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: good ? const Color(0xFF22C55E) : Colors.grey[800],
                        ),
                      );
                    },
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: good ? const Color(0xFF22C55E) : Colors.white,
                          width: 4,
                        ),
                        boxShadow: good
                            ? [BoxShadow(color: const Color(0xFF22C55E).withOpacity(0.4), blurRadius: 16)]
                            : null,
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: good ? const Color(0xFF22C55E) : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // 전면/후면 토글
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isFrontCamera = !_isFrontCamera;
                        _rebuildKey++;
                      });
                    },
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black45,
                        border: Border.all(color: Colors.white30, width: 1.5),
                      ),
                      child: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onYoloResult(List<dynamic> results) {
    if (!mounted) return;

    final all = <YOLOResult>[];
    for (final r in results) {
      if (r is YOLOResult) all.add(r);
    }

    final screen = MediaQuery.of(context).size;
    final screenArea = screen.width * screen.height;

    if (all.isEmpty) {
      setState(() {
        _mainObjects = [];
        _guideBox = null;
        _guideMsg = '';
        _score = 50;
        _msg = '피사체를 비춰주세요';
        _sceneLabel = '일반';
        _sceneIcon = '📷';
      });
      return;
    }

    // 주요 사물 필터링
    all.sort((a, b) => b.confidence.compareTo(a.confidence));
    final mainObjects = all.where((d) {
      final area = d.boundingBox.width * d.boundingBox.height;
      return area > screenArea * 0.03;
    }).take(2).toList();

    if (mainObjects.isEmpty) {
      setState(() {
        _mainObjects = [];
        _guideBox = null;
        _guideMsg = '';
        _score = 50;
        _msg = '피사체를 비춰주세요';
      });
      return;
    }

    // 씬
    bool hasPerson = mainObjects.any((d) => d.className == 'person');
    final sceneLabel = hasPerson ? '인물' : (mainObjects.length >= 2 ? '사물' : '일반');
    final sceneIcon = hasPerson ? '👤' : (mainObjects.length >= 2 ? '📦' : '📷');

    // 구도
    final mainBox = mainObjects.first.boundingBox;
    final cx = mainBox.center.dx;
    final cy = mainBox.center.dy;

    final thirdPoints = [
      Offset(screen.width / 3, screen.height / 3),
      Offset(screen.width * 2 / 3, screen.height / 3),
      Offset(screen.width / 3, screen.height * 2 / 3),
      Offset(screen.width * 2 / 3, screen.height * 2 / 3),
    ];

    Offset nearest = thirdPoints[0];
    double minDist = double.infinity;
    for (final tp in thirdPoints) {
      final dist = sqrt(pow(cx - tp.dx, 2) + pow(cy - tp.dy, 2));
      if (dist < minDist) { minDist = dist; nearest = tp; }
    }

    final guideBox = Rect.fromCenter(center: nearest, width: mainBox.width, height: mainBox.height);

    final boxAreaRatio = (mainBox.width * mainBox.height) / screenArea;
    String guideMsg = '';
    if (boxAreaRatio < 0.08) guideMsg = '더 가까이';
    else if (boxAreaRatio > 0.45) guideMsg = '좀 더 멀리';

    final maxDist = sqrt(pow(screen.width, 2) + pow(screen.height, 2)) * 0.25;
    final score = (100 * (1 - (minDist / maxDist).clamp(0, 1))).round();

    String msg;
    if (score >= 90) { msg = '지금 촬영하세요! 📸'; HapticFeedback.mediumImpact(); }
    else if (score >= 70) { msg = '거의 다 됐어요!'; }
    else { msg = '구도를 맞춰주세요'; }

    setState(() {
      _mainObjects = mainObjects;
      _guideBox = guideBox;
      _guideMsg = guideMsg;
      _score = score;
      _msg = msg;
      _sceneLabel = sceneLabel;
      _sceneIcon = sceneIcon;
    });
  }
}

class _PhotoCoachPainter extends CustomPainter {
  final List<YOLOResult> mainObjects;
  final Rect? guideBox;
  final String guideMsg;
  final Size screenSize;
  final int score;

  _PhotoCoachPainter({
    required this.mainObjects,
    required this.guideBox,
    required this.guideMsg,
    required this.screenSize,
    required this.score,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawThirdsGrid(canvas, size);

    if (mainObjects.isEmpty) return;

    // 흰색 bbox
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final whiteGlow = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (final obj in mainObjects) {
      final rrect = RRect.fromRectAndRadius(obj.boundingBox, const Radius.circular(6));
      canvas.drawRRect(rrect, whiteGlow);
      canvas.drawRRect(rrect, whitePaint);
      _drawLabel(canvas, obj.className, obj.confidence, obj.boundingBox);
    }

    // 초록색 가이드 박스
    if (guideBox != null && score < 90) {
      final greenPaint = Paint()
        ..color = const Color(0xFF22C55E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      _drawDashedRRect(canvas, RRect.fromRectAndRadius(guideBox!, const Radius.circular(6)), greenPaint);

      // 화살표
      final from = mainObjects.first.boundingBox.center;
      final to = guideBox!.center;
      if ((from - to).distance > 30) {
        final arrowPaint = Paint()
          ..color = const Color(0xFF22C55E).withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(from, to, arrowPaint);
        final angle = atan2(to.dy - from.dy, to.dx - from.dx);
        canvas.drawLine(to, Offset(to.dx - 12 * cos(angle - 0.4), to.dy - 12 * sin(angle - 0.4)), arrowPaint);
        canvas.drawLine(to, Offset(to.dx - 12 * cos(angle + 0.4), to.dy - 12 * sin(angle + 0.4)), arrowPaint);
      }

      String label = '여기로 이동';
      if (guideMsg.isNotEmpty) label = '$label · $guideMsg';
      _drawGuideLabel(canvas, label, guideBox!);
    }

    if (score >= 90) {
      _drawGoodBadge(canvas, mainObjects.first.boundingBox);
    }
  }

  void _drawLabel(Canvas canvas, String cls, double conf, Rect box) {
    final text = '$cls ${(conf * 100).toStringAsFixed(0)}%';
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = box.left; final y = box.top - tp.height - 6;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, tp.width + 10, tp.height + 4), const Radius.circular(3)),
      Paint()..color = Colors.black.withOpacity(0.55));
    tp.paint(canvas, Offset(x + 5, y + 2));
  }

  void _drawGuideLabel(Canvas canvas, String text, Rect box) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = box.center.dx - tp.width / 2; final y = box.top - tp.height - 8;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 6, y - 2, tp.width + 12, tp.height + 4), const Radius.circular(4)),
      Paint()..color = const Color(0xFF22C55E).withOpacity(0.85));
    tp.paint(canvas, Offset(x, y));
  }

  void _drawGoodBadge(Canvas canvas, Rect box) {
    final tp = TextPainter(
      text: const TextSpan(text: '좋은 위치! ✓', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = box.center.dx - tp.width / 2; final y = box.top - tp.height - 10;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 8, y - 3, tp.width + 16, tp.height + 6), const Radius.circular(6)),
      Paint()..color = const Color(0xFF22C55E));
    tp.paint(canvas, Offset(x, y));
  }

  void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint) {
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + min(10.0, metric.length - d)), paint);
        d += 18;
      }
    }
  }

  void _drawThirdsGrid(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.12)..strokeWidth = 0.5;
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), p);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), p);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), p);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), p);
    final dot = Paint()..color = Colors.white.withOpacity(0.25);
    for (final x in [size.width / 3, size.width * 2 / 3])
      for (final y in [size.height / 3, size.height * 2 / 3])
        canvas.drawCircle(Offset(x, y), 3, dot);
  }

  @override
  bool shouldRepaint(covariant _PhotoCoachPainter old) => true;
}
