import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de release (docs/compliance/RELEASE_CHECKLIST.md). android/key.properties
// está en .gitignore y lo crea el operador con storeFile, storePassword,
// keyAlias y keyPassword. Sin ese archivo, un build release de prueba se firma
// con la key de debug, pero los tasks que generan algo publicable fallan.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) keystorePropertiesFile.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

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

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Un AAB/APK de release firmado con la key de debug no se puede publicar (y
// Google Play rechaza com.example.*): se corta antes de compilar.
gradle.taskGraph.whenReady {
    val publishing = allTasks.any { it.path == ":app:bundleRelease" || it.path == ":app:assembleRelease" }
    if (!publishing) return@whenReady
    if (!hasReleaseKeystore) {
        throw GradleException(
            "Falta android/key.properties: el release no se firma con la key de debug " +
                "(docs/compliance/RELEASE_CHECKLIST.md).",
        )
    }
    if (android.defaultConfig.applicationId?.startsWith("com.example.") == true) {
        throw GradleException(
            "applicationId com.example.* no se puede publicar: definí el definitivo " +
                "(docs/compliance/RELEASE_CHECKLIST.md).",
        )
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