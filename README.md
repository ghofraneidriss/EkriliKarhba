# Ekrili Karhba

Vehicle fleet maintenance and incident management Flutter app.

## Open and run in Android Studio

1. Install the Flutter SDK and the Flutter plugin in Android Studio. In **Tools
   → SDK Manager**, install an Android SDK platform, Android SDK Build-Tools,
   Android SDK Command-line Tools, and the NDK version specified in
   `android/app/build.gradle.kts`. A compatible Java 17 runtime is also required.
2. Open this folder (`flutter_mobile_app`) in Android Studio, rather than its
   `android` subfolder.
3. Run `flutter pub get` in the project terminal, or use **Pub get** in the
   IDE's `pubspec.yaml` editor.
4. Select an Android emulator or connected Android device, then press **Run**.

The app opens on the maintenance dashboard. The bottom navigation, maintenance
forms and details, alerts, history, vehicle mileage, and incident screens are
included. The `android` Gradle project delegates compilation to Flutter. Use
Android Studio's **Run** button to launch the app; the Gradle `wrapper` task does
not launch apps.
