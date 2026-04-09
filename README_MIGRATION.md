# MobileSAM ONNX + OpenCV 외곽선 파이프라인 마이그레이션 가이드

## 1. 핵심 결론

현재 프로젝트에는 이미 **MethodChannel 기반 아키텍처**가 설계되어 있으나
(`NativeSamService.dart` → `ai_photo_coach/segmenter` 채널),
Android 쪽 `MainActivity.kt`가 비어있어 실제 세그멘테이션이 작동하지 않습니다.

이 마이그레이션은:
- **ML Kit Selfie Segmentation 제거** (pubspec에 있으나 미사용)
- **MobileSAM ONNX + OpenCV findContours** 네이티브 구현 추가
- 기존 Dart 코드(painters, models, utils) **100% 유지**
- `NativeSamService.dart`의 MethodChannel 인터페이스 **그대로 호환**

## 2. 현재 코드 분석 결과

```
패키지명: com.aiphoto.ai_photo_coach
MethodChannel: ai_photo_coach/segmenter
메서드: segmentObjects(bytes, width, height, rotation, bboxes)
반환: List<List<List<double>>> → List<List<Offset>>
```

### 기존 파이프라인 (Dart 쪽 완성, Native 쪽 미구현)
```
CameraImage → ObjectDetectorService (ML Kit)
    ↓ bboxes
NativeSamService.segmentObjects() → MethodChannel → 비어있는 MainActivity
    ↓ contour points
ContourSmoother.chaikinSmooth() → ContourPainter
    ↓
GuidePainter → CompositionEngine
```

### 교체 후 파이프라인
```
CameraImage → ObjectDetectorService (ML Kit, 유지)
    ↓ bboxes
NativeSamService.segmentObjects() → MethodChannel → SegmentationHandler
    ↓                                                  ├─ MobileSAM Encoder (ONNX)
    ↓                                                  ├─ MobileSAM Decoder (ONNX)
    ↓                                                  └─ OpenCV findContours
ContourSmoother.chaikinSmooth() → ContourPainter (유지)
    ↓
GuidePainter → CompositionEngine (유지)
```

## 3. 파일 변경 목록

### 수정 파일 (기존)
| 파일 | 변경 내용 |
|------|----------|
| `pubspec.yaml` | google_mlkit_selfie_segmentation 제거 |
| `android/app/build.gradle.kts` | ONNX Runtime + OpenCV 의존성 추가 |
| `android/app/src/main/AndroidManifest.xml` | 변경 없음 |

### 신규 파일 (Android Native)
| 파일 | 역할 |
|------|------|
| `MainActivity.kt` | MethodChannel 핸들러 (기존 빈 파일 교체) |
| `segmentation/SegmentationHandler.kt` | MobileSAM 엔진 래퍼 |
| `segmentation/MobileSamInference.kt` | ONNX Encoder + Decoder 추론 |
| `segmentation/ContourExtractor.kt` | OpenCV 마스크 → 외곽선 변환 |

### 기존 유지 파일 (Dart - 수정 없음)
- `lib/services/native_sam_service.dart` ← 인터페이스 100% 호환
- `lib/services/contour_extractor.dart` ← Chaikin 스무딩 유지
- `lib/painters/contour_painter.dart` ← 외곽선 렌더링 유지
- `lib/painters/guide_painter.dart` ← 구도 가이드 유지
- `lib/models/detected_object.dart` ← 데이터 모델 유지
- `lib/utils/composition_rules.dart` ← 구도 규칙 유지
- `lib/screens/camera_screen.dart` ← UI 유지

## 4. ONNX 모델 준비 (사전 작업)

```bash
# samexporter로 encoder/decoder 분리 export
pip install samexporter

# MobileSAM 체크포인트 다운로드
wget https://github.com/ChaoningZhang/MobileSAM/raw/master/weights/mobile_sam.pt

# ONNX export (encoder + decoder 분리)
python -m samexporter.export \
  --checkpoint mobile_sam.pt \
  --output_encoder mobile_sam_encoder.onnx \
  --output_decoder mobile_sam_decoder.onnx \
  --model-type mobile_sam \
  --quantize

# android assets 폴더에 복사
cp mobile_sam_encoder.onnx android/app/src/main/assets/
cp mobile_sam_decoder.onnx android/app/src/main/assets/
```

## 5. OpenCV Android SDK 설정

```bash
# OpenCV Android SDK 다운로드
# https://opencv.org/releases/ → Android 패키지

# 방법 A: Maven (추천)
# build.gradle.kts에 이미 포함됨

# 방법 B: 수동
# opencv-android-sdk/sdk/native/libs/ → android/app/src/main/jniLibs/
```

## 6. 성능 목표

| 단계 | 소요 시간 | 비고 |
|------|----------|------|
| ML Kit Object Detection | ~15ms | 기존 유지 |
| MobileSAM Encoder | ~8ms | Tiny-ViT 5M params |
| MobileSAM Decoder | ~4ms | Point/Box prompt |
| OpenCV Contour | ~2ms | findContours + approx |
| Chaikin Smoothing | ~1ms | Dart 측 |
| **합계** | **~30ms** | **~33 FPS (8프레임 스킵 시 실질 ~4 FPS)** |
