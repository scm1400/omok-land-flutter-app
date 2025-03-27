plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.zep_flutter_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.13113456"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            storeFile = file("keystore/release.keystore")
            storePassword = "skek2693!!" // 입력한 키스토어 비밀번호
            keyAlias = "upload"
            keyPassword = "skek2693!!" // 입력한 키 비밀번호
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.omokland.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with the release keys so `flutter build appbundle` works.
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
            
            // 네이티브 디버그 기호 설정
            ndk {
                debugSymbolLevel = "FULL" // "SYMBOL_TABLE" 또는 "FULL" 중 선택
            }
        }
    }

    bundle {
        language {
            enableSplit = true
        }
        density {
            enableSplit = true
        }
        abi {
            enableSplit = true
        }
    }
    
    buildFeatures {
        buildConfig = true
    }
}

dependencies {
    // Play Core 라이브러리 제거 및 새로운 호환 라이브러리 추가
    // implementation("com.google.android.play:core:1.10.3")
    // implementation("com.google.android.play:core-ktx:1.8.1")
    
    // Play Core 대체 라이브러리
    implementation("com.google.android.play:app-update:2.1.0")
    implementation("com.google.android.play:app-update-ktx:2.1.0")
    implementation("com.google.android.play:asset-delivery:2.1.0")
}

// 네이티브 디버그 심볼 생성 태스크
tasks.register("generateNativeSymbols") {
    doLast {
        // 매핑 파일 위치를 로그로 출력
        val mappingFile = File("$buildDir/outputs/mapping/release/mapping.txt")
        if (mappingFile.exists()) {
            logger.lifecycle("ProGuard mapping file generated at: ${mappingFile.absolutePath}")
        } else {
            logger.warn("ProGuard mapping file not found at expected location: ${mappingFile.absolutePath}")
        }
        
        // 네이티브 라이브러리 (.so) 파일 위치를 로그로 출력
        val libsDir = "$buildDir/intermediates/merged_native_libs/release/mergeReleaseNativeLibs/out/lib"
        val libsDirFile = file(libsDir)
        if (libsDirFile.exists()) {
            logger.lifecycle("Native libraries located at: ${libsDirFile.absolutePath}")
            val architectures = listOf("arm64-v8a", "armeabi-v7a", "x86", "x86_64")
            architectures.forEach { arch ->
                val archLibDir = File("$libsDir/$arch")
                if (archLibDir.exists()) {
                    val soFiles = archLibDir.listFiles()?.filter { it.name.endsWith(".so") }
                    logger.lifecycle("Found ${soFiles?.size ?: 0} .so files for $arch architecture")
                }
            }
        } else {
            logger.warn("Native libraries directory not found at: ${libsDirFile.absolutePath}")
        }
    }
}

// 네이티브 디버그 심볼 생성 및 압축 태스크
tasks.register("generateNativeDebugSymbols") {
    doLast {
        // 라이브러리 파일 위치
        val libsDir = "$buildDir/intermediates/merged_native_libs/release/mergeReleaseNativeLibs/out/lib"
        val outputDir = "$buildDir/outputs/native-debug-symbols/release"
        val libsDirFile = file(libsDir)
        val outputDirFile = file(outputDir)
        
        // 출력 디렉토리 생성
        outputDirFile.mkdirs()
        
        // 디버그 심볼 ZIP 파일 경로
        val zipFile = "$outputDir/native-debug-symbols.zip"
        
        if (libsDirFile.exists()) {
            // ZIP 파일 생성
            exec {
                workingDir = file(buildDir)
                // Windows에서는 powershell 명령어 사용
                if (System.getProperty("os.name").toLowerCase().contains("windows")) {
                    commandLine("powershell", "-Command", "Compress-Archive", "-Path", "$libsDir/*", "-DestinationPath", zipFile, "-Force")
                } else {
                    // Linux/Mac에서는 zip 명령어 사용
                    commandLine("zip", "-r", zipFile, ".")
                    workingDir = file(libsDir)
                }
            }
            
            // 생성된 ZIP 파일 확인
            val zipFileObj = file(zipFile)
            if (zipFileObj.exists()) {
                logger.lifecycle("Native debug symbols ZIP created at: ${zipFileObj.absolutePath}")
                logger.lifecycle("ZIP file size: ${zipFileObj.length() / 1024} KB")
            } else {
                logger.warn("Failed to create native debug symbols ZIP file.")
            }
        } else {
            logger.warn("Native libraries directory not found at: ${libsDirFile.absolutePath}")
        }
    }
}

// bundle 태스크 이후에 네이티브 심볼 태스크 실행
afterEvaluate {
    tasks.named("bundleReleaseResources").configure {
        finalizedBy("generateNativeSymbols", "generateNativeDebugSymbols")
    }
}

flutter {
    source = "../.."
}
