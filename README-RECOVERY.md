# AI Photo Coach - 소스 복구 가이드

## 이 ZIP에 포함된 파일 (덮어쓰기할 파일들)
```
pubspec.yaml
lib/main.dart
lib/screens/camera_screen.dart
android/app/build.gradle.kts
android/app/src/main/AndroidManifest.xml
android/app/src/main/kotlin/com/aiphoto/ai_photo_coach/MainActivity.kt
android/settings.gradle.kts
android/gradle.properties
```

## 복구 순서

### 1. 프로젝트 초기화
```bash
cd C:\Users\ykiki\StudioProjects\AI_Photo_Coach
flutter create --org com.aiphoto --project-name ai_photo_coach .
```
이렇게 하면 Flutter 기본 파일들이 재생성됩니다.

### 2. ZIP 파일 덮어쓰기
이 ZIP의 모든 파일을 프로젝트 루트에 덮어쓰기합니다.

### 3. settings.gradle 삭제 (중요!)
```bash
del android\settings.gradle
```
settings.gradle.kts만 남아야 합니다.

### 4. YOLO 모델 파일 확인
```bash
dir android\app\src\main\assets\yolo11n-seg_float32.tflite
```
없으면 Google Colab에서 다시 export:
```python
!pip install -q ultralytics
from ultralytics import YOLO
model = YOLO('yolo11n-seg.pt')
model.export(format='tflite', imgsz=640)
```
생성된 yolo11n-seg_float32.tflite를 android/app/src/main/assets/에 복사

### 5. 빌드
```bash
flutter clean
flutter pub get
flutter run --debug
```

## 주의사항
- Java 17 필수: C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot
- settings.gradle (빈 파일) 절대 존재하면 안 됨
- yolo11n-seg_float32.tflite 모델 파일 필수
