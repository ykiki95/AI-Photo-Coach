plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin은 자동으로 적용됩니다.
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

        // ONNX Runtime: ABI 필터 (앱 크기 최적화)
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // ProGuard: ONNX Runtime + OpenCV JNI 보호
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = "21"
    }

    // assets 폴더에서 ONNX 모델 압축 방지
    androidResources {
        noCompress += listOf("onnx")
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ★ MobileSAM 추론: ONNX Runtime Android
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.17.0")

    // ★ 외곽선 추출: OpenCV Android
    implementation("org.opencv:opencv:4.10.0")

    // Kotlin Coroutines (비동기 추론)
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
