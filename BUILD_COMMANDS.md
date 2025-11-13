# 🚀 Build Commands - Quick Reference

## ⚡ Quick Start (After Version Update)

```bash
cd seayou_app

# 1. Clean everything
flutter clean
rm -rf android/.gradle
rm -rf android/app/build
rm -rf build

# 2. Get dependencies
flutter pub get

# 3. Run the app
flutter run
```

---

## 📱 Development Commands

### Run App

```bash
# Debug mode (default)
flutter run

# Release mode
flutter run --release

# Profile mode (for performance testing)
flutter run --profile

# Specific device
flutter run -d <device-id>
```

### Hot Reload & Restart

```bash
# While app is running:
# Press 'r' for hot reload
# Press 'R' for hot restart
# Press 'q' to quit
```

### List Devices

```bash
flutter devices
```

---

## 🏗️ Build Commands

### Android

#### APK (for testing)

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Split APKs by ABI (smaller size)
flutter build apk --split-per-abi --release
```

#### App Bundle (for Play Store)

```bash
# Release App Bundle
flutter build appbundle --release
```

#### Output Locations

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`

### iOS (Mac only)

```bash
# Debug
flutter build ios --debug

# Release
flutter build ios --release

# Create IPA
flutter build ipa --release
```

---

## 🧹 Clean Commands

### Flutter Clean

```bash
# Clean Flutter build files
flutter clean
```

### Deep Clean (Recommended after version updates)

```bash
# Clean everything
flutter clean
rm -rf android/.gradle
rm -rf android/app/build
rm -rf build
rm -rf .dart_tool
flutter pub get
```

### Gradle Clean

```bash
cd android
./gradlew clean
cd ..
```

---

## 🔍 Diagnostic Commands

### Flutter Doctor

```bash
# Quick check
flutter doctor

# Detailed check
flutter doctor -v
```

### Check Versions

```bash
# Flutter version
flutter --version

# Gradle version
cd android
./gradlew --version
cd ..

# Dart version
dart --version
```

### Analyze Code

```bash
# Run static analysis
flutter analyze

# Format code
flutter format .
```

---

## 🧪 Testing Commands

### Run Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/widget_test.dart

# With coverage
flutter test --coverage
```

### Integration Tests

```bash
flutter drive --target=test_driver/app.dart
```

---

## 📦 Dependency Commands

### Update Dependencies

```bash
# Get dependencies
flutter pub get

# Update to latest compatible versions
flutter pub upgrade

# Update to latest major versions
flutter pub upgrade --major-versions

# Check for outdated packages
flutter pub outdated
```

---

## 🐛 Troubleshooting Commands

### Fix Common Issues

```bash
# 1. Clean everything
flutter clean
flutter pub get

# 2. If Gradle issues
cd android
./gradlew clean
./gradlew --stop
cd ..

# 3. If still issues
flutter doctor -v
flutter pub cache repair
```

### Reset Gradle

```bash
cd android
rm -rf .gradle
rm -rf app/build
./gradlew clean
cd ..
```

### Fix Gradle Daemon

```bash
cd android
./gradlew --stop
cd ..
```

---

## 🚀 Performance Commands

### Profile App

```bash
# Run in profile mode
flutter run --profile

# Open DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

### Analyze Size

```bash
# Analyze APK size
flutter build apk --analyze-size --target-platform android-arm64

# Analyze App Bundle size
flutter build appbundle --analyze-size
```

---

## 📊 Build Info Commands

### Get Build Info

```bash
# Show build configuration
cd android
./gradlew tasks
./gradlew properties
cd ..
```

### Check Dependencies

```bash
cd android
./gradlew app:dependencies
cd ..
```

---

## 🔧 Gradle Commands

### Update Gradle Wrapper

```bash
cd android
./gradlew wrapper --gradle-version 8.10.2
cd ..
```

### Gradle Build

```bash
cd android
./gradlew assembleDebug
./gradlew assembleRelease
cd ..
```

---

## 📱 Device Commands

### Android

#### Install APK

```bash
# Install debug APK
flutter install

# Install specific APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

#### Uninstall

```bash
adb uninstall com.seayou.app
```

#### View Logs

```bash
# Flutter logs
flutter logs

# Android logs
adb logcat
```

---

## 🎯 Quick Workflows

### First Time Setup

```bash
flutter doctor -v
flutter pub get
flutter run
```

### After Pulling Changes

```bash
flutter clean
flutter pub get
flutter run
```

### Before Committing

```bash
flutter analyze
flutter test
flutter format .
```

### Release Build

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

---

## 💡 Pro Tips

### Speed Up Builds

```bash
# Use specific device
flutter run -d <device-id>

# Skip unnecessary checks
flutter run --no-pub

# Use cached builds
flutter run --use-application-binary
```

### Debug Builds

```bash
# Verbose output
flutter run -v

# Trace startup
flutter run --trace-startup

# Enable observatory
flutter run --enable-observatory
```

### Release Optimization

```bash
# Obfuscate code
flutter build apk --obfuscate --split-debug-info=build/debug-info

# Tree shake icons
flutter build apk --tree-shake-icons
```

---

## 🔐 Signing (for Release)

### Generate Keystore

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Build Signed APK

```bash
flutter build apk --release
```

---

## 📝 Common Command Combinations

### Full Clean Build

```bash
flutter clean && \
rm -rf android/.gradle && \
rm -rf android/app/build && \
flutter pub get && \
flutter run
```

### Quick Test

```bash
flutter analyze && flutter test
```

### Release Workflow

```bash
flutter clean && \
flutter pub get && \
flutter test && \
flutter build appbundle --release
```

---

## ⚡ Keyboard Shortcuts (While Running)

| Key | Action                     |
| --- | -------------------------- |
| `r` | Hot reload                 |
| `R` | Hot restart                |
| `h` | Help                       |
| `d` | Detach (keep app running)  |
| `c` | Clear screen               |
| `q` | Quit                       |
| `s` | Save screenshot            |
| `w` | Dump widget hierarchy      |
| `t` | Dump rendering tree        |
| `L` | Dump layer tree            |
| `S` | Dump accessibility tree    |
| `U` | Dump semantics tree        |
| `i` | Toggle widget inspector    |
| `p` | Toggle debug painting      |
| `I` | Toggle platform mode       |
| `o` | Simulate OS change         |
| `b` | Toggle brightness          |
| `P` | Toggle performance overlay |
| `a` | Toggle timeline events     |

---

## 🎉 You're Ready!

All commands are ready to use. Start with:

```bash
cd seayou_app
flutter clean
flutter pub get
flutter run
```

Happy coding! 🚀
