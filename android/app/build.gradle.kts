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
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
