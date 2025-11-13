@echo off
echo ==========================================
echo 🚀 SeaYou App - Build and Run
echo ==========================================
echo.

echo 📍 Step 1: Cleaning project...
flutter clean
if exist android\.gradle rmdir /s /q android\.gradle
if exist android\app\build rmdir /s /q android\app\build
if exist build rmdir /s /q build
echo ✅ Clean complete!
echo.

echo 📦 Step 2: Getting dependencies...
flutter pub get
echo ✅ Dependencies installed!
echo.

echo 🔍 Step 3: Checking devices...
flutter devices
echo.

echo 🏗️ Step 4: Building and running app...
echo ⏱️ This may take 5-10 minutes on first build...
echo.

flutter run

echo.
echo ==========================================
echo ✅ Done!
echo ==========================================
pause
