pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val localPropertiesFile = file("local.properties")
        require(localPropertiesFile.exists()) {
            "Flutter SDK not configured. Install Flutter, then run `flutter pub get` from the project root."
        }
        localPropertiesFile.inputStream().use { properties.load(it) }
        properties.getProperty("flutter.sdk")
            ?: error("flutter.sdk is missing from android/local.properties")
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")

