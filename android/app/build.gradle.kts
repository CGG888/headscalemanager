import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dkstudio.headscalemanager"
    compileSdk = 36 // Updated as required by plugins
    ndkVersion = "28.2.13676358"

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    }

    // 有正式密钥库（local 或 CI secrets 注入）时用正式签名；否则回退 debug 签名。
    // 这样新克隆的仓库 / GitHub Actions 在没有密钥的情况下也能产出可安装的 release APK，
    // 而不是直接构建失败。注意：debug 签名的 APK 不能上架 Play，也不能覆盖已用正式密钥安装的应用。
    val releaseKeystoreFile = file(rootProject.projectDir.absolutePath + "/key.jks")
    val hasReleaseKeystore = keystorePropertiesFile.exists() && releaseKeystoreFile.exists()

    compileOptions {
        // Flag to enable support for the new language APIs for desugaring
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.dkstudio.headscalemanager"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packagingOptions {
        jniLibs {
            useLegacyPackaging = false
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = releaseKeystoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false

            // 先把实际要用的签名配置解析出来，再设置签名方案。
            // 注意：不能在 signingConfigs {} 块里给 "debug" 设标志——那时 AGP 还没创建
            // 它（findByName 返回 null，整块被静默跳过，v1 依然缺失）。
            val usedSigningConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // 强制 v1(JAR) + v2 + v3。
            // AGP 在 minSdk >= 24 时默认只做 v2/v3，而部分安装器（旧系统、定制 ROM、
            // MDM 管控设备）只校验 v1，缺失时会报「解析失败，安装包没有签名文件」。
            usedSigningConfig.enableV1Signing = true
            usedSigningConfig.enableV2Signing = true
            usedSigningConfig.enableV3Signing = true

            signingConfig = usedSigningConfig
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for enableEdgeToEdge() in MainActivity (Android 15+ Play compliance).
    implementation("androidx.activity:activity-ktx:1.10.1")
    // Dependency for core library desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
