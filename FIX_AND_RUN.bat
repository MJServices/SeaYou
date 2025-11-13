@echo off
echo ==========================================
echo 🔧 Fixing NDK Error and Running App
echo ==========================================
echo.

echo 📍 Cleaning project...
call flutter clean
if exist android\.gradle rmdir /s /q android\.gradle 2>nul
if exist android\app\build rmdir /s /q android\app\build 2>nul
if exist build rmdir /s /q build 2>nul
if exist android\local.properties del /q android\local.properties 2>nul
echo ✅ Clean complete!
echo.

echo 📦 Getting dependencies...
call flutter pub get
echo ✅ Dependencies installed!
echo.

echo 🏗️ Building and running app (NDK issue fixed)...
echo ⏱️ This may take a few minutes...
echo.

call flutter run

if %errorlevel% neq 0 (
    echo.
    echo ❌ Build failed!
    echo.
    echo 📋 Try these solutions:
    echo 1. Open Android Studio and install NDK from SDK Manager
    echo 2. Run: flutter doctor -v
    echo 3. Check FIX_NDK_ERROR.md for detailed solutions
    echo.
    pause
    exit /b 1
)

echo.
echo ==========================================
echo ✅ Success!
echo ==========================================
pause
