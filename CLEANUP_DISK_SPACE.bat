@echo off
echo ==========================================
echo 🧹 EMERGENCY DISK SPACE CLEANUP
echo ==========================================
echo.
echo ⚠️  WARNING: This will delete temporary files
echo     and caches to free up disk space.
echo.
pause
echo.

echo 📊 Checking current disk space...
wmic logicaldisk get caption,freespace,size
echo.

echo 🧹 Step 1: Cleaning Flutter cache...
flutter clean
echo ✅ Flutter cache cleaned!
echo.

echo 🧹 Step 2: Cleaning Gradle cache...
if exist "%USERPROFILE%\.gradle\caches" (
    echo Deleting Gradle cache...
    rmdir /s /q "%USERPROFILE%\.gradle\caches" 2>nul
    echo ✅ Gradle cache cleaned!
) else (
    echo Gradle cache already clean.
)
echo.

echo 🧹 Step 3: Cleaning Android build files...
if exist "android\.gradle" rmdir /s /q "android\.gradle" 2>nul
if exist "android\app\build" rmdir /s /q "android\app\build" 2>nul
if exist "build" rmdir /s /q "build" 2>nul
echo ✅ Build files cleaned!
echo.

echo 🧹 Step 4: Cleaning temp files...
del /q /f /s "%TEMP%\*" 2>nul
echo ✅ Temp files cleaned!
echo.

echo 🧹 Step 5: Cleaning Pub cache...
if exist "%LOCALAPPDATA%\Pub\Cache" (
    rmdir /s /q "%LOCALAPPDATA%\Pub\Cache" 2>nul
    echo ✅ Pub cache cleaned!
) else (
    echo Pub cache already clean.
)
echo.

echo 📊 Checking disk space after cleanup...
wmic logicaldisk get caption,freespace,size
echo.

echo ==========================================
echo ✅ Cleanup Complete!
echo ==========================================
echo.
echo 💡 Next steps:
echo    1. Check if you have at least 10 GB free
echo    2. If yes, run: flutter pub get
echo    3. Then run: flutter run
echo.
echo 💡 If still low on space:
echo    - Empty Recycle Bin
echo    - Run Windows Disk Cleanup (cleanmgr)
echo    - Move files to another drive
echo.
pause
