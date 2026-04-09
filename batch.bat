# 1. 루트 설정 파일을 Git 관리 대상에 추가
git add android/build.gradle.kts

# 2. 현재 작업 중인 수정 사항들도 추가
git add android/app/build.gradle.kts lib/screens/camera_screen.dart

# 3. 로컬 저장소에 저장 (메모 남기기)
git commit -m "Fix: Restore root build.gradle and update camera screen"

# 4. GitHub로 전송
git push origin main