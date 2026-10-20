# ControlDeck — iOS, Android and Web setup

This repository contains the Flutter application source. The platform runner folders must exist before Flutter can launch the corresponding target.

## 1. Check the local Flutter installation

From the repository root:

```bash
flutter doctor -v
flutter --version
flutter devices
```

Resolve any Flutter Doctor issues shown for the platform you intend to run.

## 2. Generate missing platform folders

If this checkout does not contain `android/`, `ios/`, or `web/`, run this once from the project root:

```bash
flutter create --platforms=android,ios,web .
```

Review the generated changes before committing them. Do not run this command from a parent folder or over unrelated project files.

## 3. Configure ControlDeck sign-in

Create a dedicated Supabase project for ControlDeck, then apply `supabase/controldeck_schema.sql` in its SQL editor. Create or invite your account through Supabase Auth. Do not add passwords, service-role keys, or database credentials to Dart files or Git.

Run with the project URL and publishable/anon key:

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

The login screen is intentionally unavailable until these values are configured; this avoids bypassing authentication when configuration is missing.

## 4. Run on each platform

### Android

Install Android Studio and an Android SDK, accept the required licences with `flutter doctor --android-licenses`, then start an emulator or connect an Android device with USB debugging enabled.

```bash
flutter devices
flutter run -d <android-device-id>
```

### iOS

iOS builds require macOS with Xcode installed. Open Xcode once, install its required components, and start an iOS Simulator. Then:

```bash
open -a Simulator
flutter devices
flutter run -d <ios-simulator-id>
```

For a physical iPhone, connect it to the Mac, trust the computer, enable Developer Mode if prompted, and configure signing in Xcode for release/deployment.

### Web

After generating the web runner if it is missing:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

### macOS desktop

A device appearing in `flutter devices` does not guarantee that the repository has a macOS runner. If desktop support is needed and the `macos/` folder is absent, generate it with:

```bash
flutter create --platforms=macos .
flutter run -d macos
```

## 5. Verify before committing

```bash
flutter pub get
flutter analyze
flutter test
```

Run the build for each target you plan to distribute. The source review and feature-parity checklist is in [PROJECT_REVIEW_AND_PORT_PLAN.md](PROJECT_REVIEW_AND_PORT_PLAN.md). A successful documentation commit is not evidence that iOS/Android builds or all project workflows have been tested.
