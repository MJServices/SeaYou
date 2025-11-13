# SeaYou App - Setup Instructions

## Overview

This is the SeaYou dating app built to match the Figma design 100%. The app includes a Home screen with bottle messaging functionality, mood-based gradients, and a complete navigation system.

## Required Assets

### 1. Images

Place the following images in `assets/images/`:

- `background.jpg` - Background image for the home screen (360x460px)
- `profile.jpg` - User profile picture (circular, 24x24px minimum)
- `photo_stamp.jpg` - Sample photo for photo stamp bottles

### 2. Fonts

Download Montserrat font from [Google Fonts](https://fonts.google.com/specimen/Montserrat) and place in `assets/fonts/`:

- `Montserrat-Regular.ttf` (400 weight)
- `Montserrat-Medium.ttf` (500 weight)
- `Montserrat-SemiBold.ttf` (600 weight)

Then uncomment the fonts section in `pubspec.yaml`.

## Design Specifications

### Colors

- Primary: `#0AC5C5` (Teal)
- Background: `#FFFFFF` (White)
- Text Primary: `#151515` (Dark Gray)
- Text Secondary: `#737373` (Medium Gray)
- Text Tertiary: `#363636` (Dark Gray)
- Border: `#E3E3E3` (Light Gray)
- Background Secondary: `#F8F8F8` (Off White)

### Mood Gradients

1. **Dreamy**: Radial gradient from `#9B98E6` to `#C7CEEA`
2. **Curious**: Radial gradient from `#FFC700` to `#D89736`
3. **Calm**: Linear gradient from `#9ECFD4` to `#65ADA9`
4. **Playful**: Linear gradient from `#FF9F9B` to `#FF6D68`

### Typography

- **Display Text**: Montserrat 20px, Weight 500, Line height 1.2
- **Body Text**: Montserrat 16px, Weight 500, Line height 1.5
- **Label Text**: Montserrat 14px, Weight 400, Line height 1.5
- **Label Small**: Montserrat 12px, Weight 400, Line height 1.5

### Spacing

- Screen padding: 16px horizontal
- Card border radius: 8px (buttons), 16px (cards), 20px (large cards), 24px (modals)
- Gap between elements: 8px, 12px, 16px, 20px, 24px

## Screens Implemented

### 1. Home Screen (`home_screen.dart`)

- Displays user greeting with profile picture
- Shows bottle count (32 bottles received)
- "View bottle messages" button
- Sent bottles card with different bottle types:
  - Voice Chat (with audio waveform)
  - Text (with preview)
  - Photo Stamp (with image)
  - See all button
- Floating action button (+) to send new bottle
- Bottom navigation bar (Home, Chat, Profile)
- Bottle message overlay with mood-based gradient

### 2. Send Bottle Screen (`send_bottle_screen.dart`)

- Header with Cancel, Type selector, and Drafts
- Mood selector (Dreamy, Curious, Calm, Playful)
- Text input area (max 400 characters)
- Preview button (enabled when text is entered)
- Preview modal with mood gradient
- Send confirmation modal

### 3. Received Bottles Screen (`received_bottles_screen.dart`)

- List of received bottles
- Back button navigation
- Note about bottle expiration (30 days)

### 4. Sent Bottles Screen (`sent_bottles_screen.dart`)

- List of sent bottles
- Back button navigation
- Note about bottle expiration (30 days)

## Widgets

### Custom Widgets

1. **CustomStatusBar** (`status_bar.dart`) - iPhone-style status bar
2. **CustomNavigationBar** (`navigation_bar.dart`) - Bottom navigation with 3 tabs
3. **BottleCard** (`bottle_card.dart`) - Reusable card for displaying bottles
4. **CustomButton** (`custom_button.dart`) - Styled button component
5. **CustomTextField** (`custom_text_field.dart`) - Styled text input

## Running the App

1. Ensure Flutter is installed and configured
2. Add required assets to the folders mentioned above
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the app

## Design Principles

The app follows these design principles from the Figma file:

- Clean, minimal interface with focus on content
- Mood-based color gradients for emotional expression
- Consistent spacing and typography
- Smooth transitions and interactions
- Mobile-first design (iPhone 16 Pro dimensions)

## Notes

- The app uses the Montserrat font family throughout
- All colors match the Figma design exactly
- Spacing and sizing follow the 8px grid system
- Border radius values are consistent across components
- The design supports both light mode (currently implemented)
