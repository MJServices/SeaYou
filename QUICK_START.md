# SeaYou App - Quick Start Guide

## 🚀 Get Running in 5 Minutes

### Step 1: Install Flutter (if not already installed)

**Windows:**

```bash
# Download Flutter SDK from https://flutter.dev/docs/get-started/install/windows
# Extract to C:\flutter
# Add C:\flutter\bin to PATH
```

**Mac:**

```bash
# Download Flutter SDK from https://flutter.dev/docs/get-started/install/macos
# Extract to ~/flutter
# Add export PATH="$PATH:~/flutter/bin" to ~/.zshrc or ~/.bash_profile
```

**Linux:**

```bash
# Download Flutter SDK from https://flutter.dev/docs/get-started/install/linux
# Extract to ~/flutter
# Add export PATH="$PATH:~/flutter/bin" to ~/.bashrc
```

### Step 2: Verify Installation

```bash
flutter doctor
```

Fix any issues shown (Android Studio, Xcode, etc.)

### Step 3: Get Fonts

1. Download Montserrat from: https://fonts.google.com/specimen/Montserrat
2. Extract and copy these 3 files to `seayou_app/assets/fonts/`:
   - Montserrat-Regular.ttf
   - Montserrat-Medium.ttf
   - Montserrat-SemiBold.ttf

### Step 4: Install Dependencies

```bash
cd seayou_app
flutter pub get
```

### Step 5: Run the App

**Option A: Using Command Line**

```bash
flutter run
```

**Option B: Using VS Code**

1. Open project in VS Code
2. Press F5 or click "Run" → "Start Debugging"

**Option C: Using Android Studio**

1. Open project in Android Studio
2. Click the green play button

## 📱 Device Setup

### Android Emulator

1. Open Android Studio
2. Tools → AVD Manager
3. Create Virtual Device
4. Select a device (e.g., Pixel 6)
5. Download system image (API 34 recommended)
6. Start emulator

### iOS Simulator (Mac only)

1. Open Xcode
2. Xcode → Open Developer Tool → Simulator
3. Choose device (e.g., iPhone 15)

### Physical Device

**Android:**

1. Enable Developer Options on phone
2. Enable USB Debugging
3. Connect via USB
4. Run `flutter devices` to verify

**iOS:**

1. Connect iPhone via USB
2. Trust computer on device
3. Run `flutter devices` to verify

## 🎯 What You'll See

The app will start with a beautiful splash screen showing:

- Animated background circles
- Profile placeholders
- Interest tags
- "Get Started" button

Then you'll go through:

1. Language selection
2. Email registration
3. Verification code
4. Password creation
5. Profile setup (5 steps)
6. Completion screen

## 🛠️ Common Commands

```bash
# Run app
flutter run

# Run with hot reload
flutter run --hot

# Build APK (Android)
flutter build apk

# Build for iOS
flutter build ios

# Clean build
flutter clean

# Get dependencies
flutter pub get

# Check for issues
flutter doctor

# List connected devices
flutter devices

# Run tests
flutter test
```

## 📂 Project Structure at a Glance

```
seayou_app/
├── lib/
│   ├── main.dart              # Start here
│   ├── screens/               # 11 screens
│   ├── widgets/               # Reusable components
│   └── utils/                 # Colors & styles
├── assets/
│   └── fonts/                 # Add Montserrat fonts here
└── pubspec.yaml               # Dependencies
```

## 🎨 Key Features

- ✅ 11 beautiful screens
- ✅ Form validation
- ✅ Password strength checker
- ✅ Multi-step profile setup
- ✅ Interest selection (77 options!)
- ✅ Smooth navigation
- ✅ Custom components

## 🐛 Troubleshooting

**"Flutter command not found"**
→ Add Flutter to PATH

**"No devices found"**
→ Start emulator or connect device

**"Fonts not showing"**
→ Check fonts are in assets/fonts/

**"Build failed"**
→ Run `flutter clean` then `flutter pub get`

**"Hot reload not working"**
→ Press 'R' in terminal or restart app

## 📖 Next Steps

1. ✅ Run the app
2. ✅ Go through the onboarding flow
3. ✅ Explore the code
4. 📝 Read PROJECT_SUMMARY.md for details
5. 📝 Read SETUP_GUIDE.md for advanced setup
6. 🚀 Start building main features!

## 💡 Tips

- Use hot reload (press 'r' in terminal) for quick changes
- Use hot restart (press 'R') for bigger changes
- Check console for errors
- Use Flutter DevTools for debugging
- Read inline code comments

## 🎓 Learning Resources

- Flutter Docs: https://flutter.dev/docs
- Flutter Cookbook: https://flutter.dev/docs/cookbook
- Widget Catalog: https://flutter.dev/docs/development/ui/widgets
- YouTube: Flutter Official Channel

## ✨ You're Ready!

The app is fully functional and ready to run. Just follow the steps above and you'll be exploring the SeaYou onboarding experience in minutes!

Happy coding! 🎉
