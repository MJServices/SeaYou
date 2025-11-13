@echo off
echo ==========================================
echo 🔧 SeaYou App - FIXED VERSION
echo ==========================================
echo.
echo ✅ Kotlin 2.1.0 (latest)
echo ✅ NDK disabled (saves disk space)
echo ✅ Optimized build
echo.
echo ==========================================
echo.

echo 📍 Cleaning project...
flutter clean
if exist android\.gradle rmdir /s /q android\.gradle 2>nul
if exist android\app\build rmdir /s /q android\app\build 2>nul
if exist build rmdir /s /q build 2>nul
echo ✅ Clean complete!
echo.

echo 📦 Getting dependencies...
flutter pub get
echo ✅ Dependencies ready!
echo.

echo 🔍 Checking devices...
flutter devices
echo.

echo 🏗️ Building app (without NDK)...
echo ⏱️ First build: 3-5 minutes
echo.

flutter run

echo.
echo ==========================================
echo ✅ Done!
echo ==========================================
pause
