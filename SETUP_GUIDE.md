# SeaYou App - Complete Setup Guide

## Prerequisites

Before you begin, ensure you have the following installed:

1. **Flutter SDK** (version 3.0.0 or higher)

   - Download from: https://flutter.dev/docs/get-started/install
   - Follow the installation guide for your operating system (Windows/Mac/Linux)

2. **Android Studio** (for Android development)

   - Download from: https://developer.android.com/studio
   - Install Flutter and Dart plugins

3. **Xcode** (for iOS development - Mac only)

   - Download from Mac App Store
   - Install Xcode Command Line Tools

4. **VS Code** (optional but recommended)
   - Download from: https://code.visualstudio.com/
   - Install Flutter and Dart extensions

## Step-by-Step Setup

### 1. Verify Flutter Installation

Open a terminal/command prompt and run:

```bash
flutter doctor
```

This will check your environment and display a report. Fix any issues shown.

### 2. Download Fonts

1. Go to https://fonts.google.com/specimen/Montserrat
2. Click "Download family"
3. Extract the ZIP file
4. Copy these files to `seayou_app/assets/fonts/`:
   - Montserrat-Regular.ttf
   - Montserrat-Medium.ttf
   - Montserrat-SemiBold.ttf

### 3. Install Dependencies

Navigate to the project directory and run:

```bash
cd seayou_app
flutter pub get
```

### 4. Run the App

#### On Android Emulator:

1. Open Android Studio
2. Start an Android Virtual Device (AVD)
3. Run: `flutter run`

#### On iOS Simulator (Mac only):

1. Open Xcode
2. Start iOS Simulator
3. Run: `flutter run`

#### On Physical Device:

1. Enable Developer Mode on your device
2. Connect via USB
3. Run: `flutter run`

## Project Structure

```
seayou_app/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── screens/                           # All screens
│   │   ├── splash_screen.dart             # Initial splash screen
│   │   ├── language_selection_screen.dart # Language selection
│   │   ├── create_account_screen.dart     # Email input
│   │   ├── verification_screen.dart       # 6-digit code verification
│   │   ├── create_password_screen.dart    # Password creation
│   │   ├── profile_info_screen.dart       # Personal info (1/5)
│   │   ├── sexual_orientation_screen.dart # Orientation selection (2/5)
│   │   ├── expectations_screen.dart       # Dating expectations (3/5)
│   │   ├── interests_screen.dart          # Interest selection (4/5)
│   │   ├── upload_picture_screen.dart     # Profile picture (5/5)
│   │   └── account_setup_done_screen.dart # Completion screen
│   ├── widgets/                           # Reusable widgets
│   │   ├── custom_button.dart             # Styled button
│   │   ├── custom_text_field.dart         # Styled input field
│   │   └── status_bar.dart                # Custom status bar
│   └── utils/                             # Utilities
│       ├── app_colors.dart                # Color constants
│       └── app_text_styles.dart           # Text style constants
├── assets/
│   ├── fonts/                             # Font files
│   ├── images/                            # Image assets
│   └── icons/                             # Icon assets
├── android/                               # Android configuration
├── ios/                                   # iOS configuration
└── pubspec.yaml                           # Dependencies

```

## Features Implemented

### 1. Splash Screen

- Animated background with decorative circles
- Profile image placeholders
- Interest tags
- "Get Started" button

### 2. Language Selection

- Multiple language options
- Radio button selection
- Device language default

### 3. Account Creation

- Email validation
- Real-time input validation
- Terms acceptance
- Link to sign in

### 4. Email Verification

- 6-digit code input
- Auto-focus on next field
- Resend code timer
- Back navigation

### 5. Password Creation

- Password visibility toggle
- Real-time validation:
  - Minimum 8 characters
  - At least one symbol
  - At least one number
- Visual feedback for requirements

### 6. Profile Information (1/5)

- Full name input
- Age input
- City selection (dropdown)
- About section (80 character limit)
- Character counter
- Progress indicator

### 7. Sexual Orientation (2/5)

- Multiple selection
- Predefined options
- Custom input option
- Show on profile toggle
- Progress indicator

### 8. Expectations (3/5)

- Relationship type selection
- Gender preference selection
- Single selection per category
- Progress indicator

### 9. Interests (4/5)

- Multiple categories:
  - Movies & Series
  - Sports & Games
  - Pets
  - Activities
  - Creative
  - Restaurants
  - Meditation
- Minimum 2 selections required
- Chip-based selection
- Skip option
- Progress indicator

### 10. Upload Picture (5/5)

- Profile picture placeholder
- Gallery upload option
- Camera option (disabled)
- Skip option
- Progress indicator

### 11. Account Setup Complete

- Success message
- How it works explanation
- Animated bubbles background
- "Let's go!" button

## Color Scheme

- **Primary**: #0AC5C5 (Cyan)
- **White**: #FFFFFF
- **Black**: #151515
- **Grey**: #737373
- **Light Grey**: #E3E3E3
- **Dark Grey**: #363636
- **Background**: #F8F8F8
- **Error**: #FB3748
- **Purple**: #620071
- **Light Purple**: #F2DEFF
- **Yellow**: #FFD580

## Typography

- **Font Family**: Montserrat
- **Display Text**: 20px, Medium (500)
- **Body Text**: 16px, Medium (500)
- **Label Text**: 14px, Regular (400)
- **Large Title**: 40px, SemiBold (600)
- **Medium Title**: 24px, SemiBold (600)

## Common Issues & Solutions

### Issue: "Flutter command not found"

**Solution**: Add Flutter to your PATH environment variable

### Issue: "Unable to locate Android SDK"

**Solution**: Set ANDROID_HOME environment variable to your Android SDK location

### Issue: "CocoaPods not installed" (iOS)

**Solution**: Run `sudo gem install cocoapods`

### Issue: "Fonts not displaying correctly"

**Solution**: Ensure font files are in assets/fonts/ and pubspec.yaml is configured correctly

### Issue: "Hot reload not working"

**Solution**: Try hot restart (Shift + R in terminal) or full restart

## Running Tests

```bash
flutter test
```

## Building for Production

### Android APK:

```bash
flutter build apk --release
```

### iOS IPA (Mac only):

```bash
flutter build ios --release
```

## Next Steps

After completing the onboarding flow, you can extend the app with:

1. **Authentication Backend**

   - Firebase Authentication
   - Email verification
   - Password reset

2. **Main App Features**

   - Anonymous messaging
   - Bottle sending/receiving
   - Feeling bar progress
   - Profile reveal
   - Matching algorithm

3. **Additional Screens**

   - Home/Dashboard
   - Messages/Chat
   - Profile view
   - Settings
   - Subscription/Pro plan

4. **State Management**

   - Provider
   - Riverpod
   - Bloc

5. **Backend Integration**
   - REST API
   - Firebase
   - GraphQL

## Support

For Flutter documentation and resources:

- Official Docs: https://flutter.dev/docs
- Flutter Community: https://flutter.dev/community
- Stack Overflow: https://stackoverflow.com/questions/tagged/flutter

## License

This project is created for demonstration purposes based on the SeaYou Figma design.
