plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.ar_makeup_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.ar_makeup_app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

configurations.all {
    resolutionStrategy {
        eachDependency {
            // core-viewtree no existe en 1.13.1: lo pide androidx.lifecycle 2.10
            // (vía LiteRT, el runtime del tracker del motor AR).
            if (requested.group == "androidx.core" && !requested.name.contains("core-backported-fixes") &&
                requested.name != "core-viewtree"
            ) {
                useVersion("1.13.1")
            }
            if (requested.group == "androidx.activity") {
                useVersion("1.9.3")
            }
            if (requested.group == "androidx.navigationevent") {
                useVersion("1.0.0")
            }
        }
    }
}