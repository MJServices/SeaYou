# Home Screen Implementation

## Overview

The home screen has been implemented to match the Figma design exactly, including all colors, icons, and layout specifications.

## Features Implemented

### 1. Header Section

- Profile avatar (24x24px circle)
- Greeting text "Hey Alex" in Montserrat Medium 16px

### 2. Hero Section

- Large hero image (360x460px)
- "32 bottles received" text in Montserrat Medium 20px
- "View bottle messages" button with cyan border and background

### 3. Sent Bottles Section

- White card container with rounded corners (20px)
- "Sent Bottles (24)" header
- 4 bottle cards in 2x2 grid:
  - Voice Chat card (white background)
  - Text card (light purple background) with message preview
  - Photo Stamp card (light orange background) with image
  - "See all" card (light pink background) with arrow

### 4. Floating Action Button

- Cyan circular button (56x56px)
- Plus icon in white
- Drop shadow effect
- Positioned bottom right

### 5. Bottom Navigation

- 3 navigation items: Home, Chat, Profile
- Home is active (cyan color)
- Others are inactive (gray color)
- Profile shows avatar instead of icon

## Colors Used

- Primary Cyan: `#0AC5C5`
- Background White: `#FFFFFF`
- Card Background: `#FCFCFC`
- Text Dark: `#151515`
- Text Gray: `#737373`
- Border: `#E3E3E3`
- Button Background: `#ECFAFA`

## Assets Downloaded

- `profile_avatar.png` - User profile picture
- `hero_image.png` - Main hero image (345x722px)
- `photo_stamp.png` - Photo for stamp card (479x319px)
- `plus_button.svg` - Plus icon for FAB

## Typography

- Font Family: Montserrat (primary), Inter (navigation)
- Weights: Regular (400), Medium (500)
- Sizes: 12px, 14px, 16px, 20px

## Layout Specifications

- Screen width: 402px (iPhone 16 Pro Max)
- Content padding: 16px horizontal
- Card border radius: 16px (bottles), 20px (container)
- Button border radius: 8px
- Gap between cards: 20px

## Running the App

```bash
flutter run
```

Make sure you have:

1. Flutter SDK installed
2. An emulator running or device connected
3. All dependencies installed (`flutter pub get`)
