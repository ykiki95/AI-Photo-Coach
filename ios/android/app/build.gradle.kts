plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    namespace = "com.aiphoto.ai_photo_coach"

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "com.aiphoto.ai_photo_coach"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

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
    // ML Kit Subject Segmentation은 Flutter 플러그인이 자동 관리
    // 추가 네이티브 의존성 불필요
}
