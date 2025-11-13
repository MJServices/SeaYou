# SeaYou - Dating App

A Flutter dating app with anonymous messaging feature based on Figma design.

## Features

- Splash Screen with animated elements
- Language Selection
- Account Creation with Email Verification
- Password Creation with validation
- Profile Setup (Personal Info, Sexual Orientation, Expectations, Interests)
- Profile Picture Upload
- Onboarding completion screen

## Getting Started

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK
- Android Studio / Xcode for mobile development

### Installation

1. Clone the repository
2. Navigate to the project directory:

   ```bash
   cd seayou_app
   ```

3. Install dependencies:

   ```bash
   flutter pub get
   ```

4. **Important**: Download Montserrat fonts (see FONT_SETUP.md)

5. Run the app:
   ```bash
   flutter run
   ```

### ✅ Android V2 Embedding

This project uses **Android V2 embedding** (latest standard). All Android configuration files are already set up correctly:

- Gradle 8.3
- Android Gradle Plugin 8.1.0
- Kotlin 1.9.10
- Modern FlutterActivity

See `ANDROID_V2_MIGRATION.md` for complete details.

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── screens/                  # All app screens
│   ├── splash_screen.dart
│   ├── language_selection_screen.dart
│   ├── create_account_screen.dart
│   ├── verification_screen.dart
│   ├── create_password_screen.dart
│   ├── profile_info_screen.dart
│   ├── sexual_orientation_screen.dart
│   ├── expectations_screen.dart
│   ├── interests_screen.dart
│   ├── upload_picture_screen.dart
│   └── account_setup_done_screen.dart
├── widgets/                  # Reusable widgets
│   ├── custom_button.dart
│   ├── custom_text_field.dart
│   └── status_bar.dart
└── utils/                    # Utilities
    ├── app_colors.dart
    └── app_text_styles.dart
```

## Design

This app is based on the Figma design "SeaYou" with the following color scheme:

- Primary: #0AC5C5 (Cyan)
- Background: #FFFFFF (White)
- Text: #151515 (Black)
- Secondary Text: #737373 (Grey)

## Fonts

The app uses Montserrat font family. Make sure to add the font files to:

```
assets/fonts/
├── Montserrat-Regular.ttf
├── Montserrat-Medium.ttf
└── Montserrat-SemiBold.ttf
```

## Notes

- This is the onboarding flow implementation
- Main app features (messaging, matching, etc.) are not included in this version
- Images and icons need to be added to assets/images/ and assets/icons/
- Font files need to be downloaded and added to assets/fonts/

## License

This project is created for demonstration purposes.
