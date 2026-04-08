plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin은 자동으로 적용됩니다.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // [수정 포인트 1] 최신 라이브러리 호환을 위해 36으로 설정
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    namespace = "com.aiphoto.ai_photo_coach"

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        // 앱의 고유 아이디입니다.
        applicationId = "com.aiphoto.ai_photo_coach"

        // [수정 포인트 2] ML Kit(AI) 작동을 위한 최소 버전 24 설정
        minSdk = 24

        // [수정 포인트 3] 최신 안드로이드 타겟 버전 36 설정
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 디버그 키로 서명 설정 (개발 단계)
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    // 이 부분을 추가하세요
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = "21"
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 추가적인 네이티브 의존성이 필요할 때 여기에 작성합니다.
}