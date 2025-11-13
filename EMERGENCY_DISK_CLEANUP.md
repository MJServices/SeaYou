# 🚨 EMERGENCY: Out of Disk Space!

## ❌ Current Problem

```
FileSystemException: There is not enough space on the disk
```

Your **C: drive is full**. You need to free up space immediately!

---

## 🔍 Check Your Disk Space

Run this in PowerShell:

```powershell
Get-PSDrive C | Select-Object Used,Free
```

You need at least **10 GB free** on C: drive.

---

## 🧹 IMMEDIATE CLEANUP (Do These Now!)

### 1. Clean Temp Files (Frees 2-5 GB)

```powershell
# Run as Administrator in PowerShell
Remove-Item -Path $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path C:\Windows\Temp\* -Recurse -Force -ErrorAction SilentlyContinue
```

### 2. Empty Recycle Bin

Right-click Recycle Bin → Empty Recycle Bin

### 3. Clean Flutter Cache (Frees 1-2 GB)

```powershell
flutter clean
Remove-Item -Recurse -Force $env:LOCALAPPDATA\Pub\Cache -ErrorAction SilentlyContinue
```

### 4. Clean Gradle Cache (Frees 2-5 GB)

```powershell
Remove-Item -Recurse -Force $env:USERPROFILE\.gradle\caches -ErrorAction SilentlyContinue
```

### 5. Clean Android Build Files (Frees 1-2 GB)

```powershell
cd C:\Users\minha\OneDrive\Documents\code\FLutter\datingAPp\seayou_app
Remove-Item -Recurse -Force android\.gradle -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force android\app\build -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
```

---

## 🎯 ONE COMMAND TO CLEAN EVERYTHING

Copy and paste this in **PowerShell (Run as Administrator)**:

```powershell
# Clean temp files
Remove-Item -Path $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path C:\Windows\Temp\* -Recurse -Force -ErrorAction SilentlyContinue

# Clean Flutter cache
flutter clean
Remove-Item -Recurse -Force $env:LOCALAPPDATA\Pub\Cache -ErrorAction SilentlyContinue

# Clean Gradle cache
Remove-Item -Recurse -Force $env:USERPROFILE\.gradle\caches -ErrorAction SilentlyContinue

# Clean Android Studio cache
Remove-Item -Recurse -Force $env:USERPROFILE\.android\build-cache -ErrorAction SilentlyContinue

Write-Host "✅ Cleanup complete! Check disk space now."
```

---

## 💾 Additional Cleanup Options

### 6. Run Windows Disk Cleanup

1. Press `Win + R`
2. Type: `cleanmgr`
3. Select C: drive
4. Check all boxes
5. Click OK

This can free up **5-10 GB**!

### 7. Uninstall Unused Programs

1. Settings → Apps → Installed apps
2. Uninstall programs you don't use

### 8. Move Files to Another Drive

Move large files from C: to D: or external drive:

- Downloads folder
- Videos
- Documents
- Pictures

### 9. Clean OneDrive Cache

```powershell
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Microsoft\OneDrive\logs" -ErrorAction SilentlyContinue
```

### 10. Delete Old Windows Updates

```powershell
# Run as Administrator
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
```

This can free up **3-5 GB**!

---

## 🎯 RECOMMENDED: Move Android SDK

If you have another drive (D:, E:, etc.), move Android SDK there:

### Step 1: Move SDK

```powershell
# Example: Move to D: drive
xcopy "C:\Users\minha\AppData\Local\Android\Sdk" "D:\Android\Sdk" /E /I /H
```

### Step 2: Update Android Studio

1. Open Android Studio
2. File → Settings → Appearance & Behavior → System Settings → Android SDK
3. Change SDK Location to: `D:\Android\Sdk`
4. Click Apply

### Step 3: Update Environment Variable

1. Press `Win + R`, type: `sysdm.cpl`
2. Advanced → Environment Variables
3. Edit `ANDROID_HOME` to: `D:\Android\Sdk`

---

## 🔍 Find Large Files

Find what's taking up space:

```powershell
# Find large files on C: drive
Get-ChildItem C:\ -Recurse -ErrorAction SilentlyContinue |
    Where-Object {$_.Length -gt 100MB} |
    Sort-Object Length -Descending |
    Select-Object FullName, @{Name="Size(MB)";Expression={[math]::Round($_.Length/1MB,2)}} |
    Format-Table -AutoSize
```

---

## ✅ After Cleanup - Verify Space

```powershell
Get-PSDrive C | Select-Object Used,Free
```

You should have at least **10 GB free**.

---

## 🚀 Then Try Building Again

After freeing up space:

```powershell
cd C:\Users\minha\OneDrive\Documents\code\FLutter\datingAPp\seayou_app

flutter clean
flutter pub get
flutter run
```

---

## 📊 Disk Space Requirements

| Component            | Space Needed |
| -------------------- | ------------ |
| Windows System       | 20 GB        |
| Flutter SDK          | 2 GB         |
| Android SDK          | 5 GB         |
| Gradle Cache         | 2 GB         |
| Build Files          | 2 GB         |
| Temp Files           | 2 GB         |
| **Minimum Free**     | **10 GB**    |
| **Recommended Free** | **20 GB**    |

---

## 🆘 If Still Out of Space

### Option 1: Use Another Drive

Move your project to D: drive:

```powershell
# Move project
xcopy "C:\Users\minha\OneDrive\Documents\code\FLutter\datingAPp\seayou_app" "D:\Projects\seayou_app" /E /I /H

# Then work from D:
cd D:\Projects\seayou_app
flutter run
```

### Option 2: Upgrade Your Disk

If C: drive is too small, consider:

- Adding a new hard drive
- Upgrading to a larger SSD
- Using external storage

### Option 3: Use Cloud Storage

Move OneDrive files to online-only:

1. Right-click OneDrive folder
2. Free up space
3. Select folders to keep online-only

---

## 🎯 Quick Summary

**Immediate Actions:**

1. ✅ Clean temp files (2-5 GB)
2. ✅ Empty Recycle Bin (varies)
3. ✅ Clean Gradle cache (2-5 GB)
4. ✅ Run Disk Cleanup (5-10 GB)
5. ✅ Delete old files (varies)

**Target:** At least 10 GB free on C: drive

**Then:** Run `flutter clean && flutter pub get && flutter run`

---

## 💡 Pro Tip

Set up automatic cleanup:

1. Settings → System → Storage
2. Turn on "Storage Sense"
3. Configure to clean automatically

---

**You MUST free up disk space before building the app!**

Run the cleanup commands above, then try building again. 🚀
