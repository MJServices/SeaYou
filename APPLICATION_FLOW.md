# SeaYou Dating App - Application Flow & Navigation Documentation

## Overview
SeaYou is a Flutter-based dating app with anonymous messaging features. The app uses a bottom navigation bar with three main tabs: Home, Chat, and Profile.

## Main Navigation Structure

### Bottom Navigation Bar
- **Location**: Fixed at the bottom of all main screens
- **Height**: 76px
- **Background Color**: `#F8F8F8`
- **Tabs**:
  1. **Home** (Index 0)
     - Icon: `assets/icons/home_simple.svg`
     - Active Color: `#0AC5C5`
     - Inactive Color: `#737373`
  2. **Chat** (Index 1)
     - Icon: `assets/icons/chat_lines.svg`
     - Active Color: `#0AC5C5`
     - Inactive Color: `#737373`
  3. **Profile** (Index 2)
     - Avatar: `assets/images/profile_avatar.png` (24x24px circle)
     - Active Color: `#0AC5C5` (text)
     - Inactive Color: `#737373` (text)

## Application Flow

### 1. Home Tab (`lib/screens/home_screen.dart`)
**Status**: ✅ Built

**Features**:
- Hero section with decorative circles and profile image
- "32 bottles received" display
- "View bottle messages" button → Navigates to `ReceivedBottlesViewer`
- Sent Bottles section (24 bottles)
  - Voice Chat card → Opens `VoiceChatModal`
  - Text message card → Navigates to `BottleDetailScreen`
  - Photo Stamp card → Opens `PhotoStampModal`
  - "See all" card → Navigates to `AllBottlesScreen`
- Floating Action Button (Plus icon) → Navigates to `SendBottleScreen`
- Bottom Navigation Bar

**Navigation From Home**:
- Profile avatar tap → Profile Screen (to be built)
- Chat icon tap → Chat Screen
- Plus button → Send Bottle Screen

### 2. Chat Tab (`lib/screens/chat/chat_screen.dart`)
**Status**: ✅ Built

**Main Screen**: `ChatListScreen`

**Features**:
- Header with "Connections" title and search icon
- Filter tabs: All, Unlocked, Anon
- Conversation list with:
  - Avatar (gradient circles for anonymous, profile images for unlocked)
  - Name
  - Last message preview
  - Time stamp
  - Message type indicators (voice, image, text)
- "View Archived (32)" button → Navigates to `ArchivedChatsScreen`
- Bottom Navigation Bar

**Navigation From Chat**:
- Conversation item tap → `ChatConversationScreen`
- Search icon → Opens search dialog
- Archive button → `ArchivedChatsScreen`
- Home icon → Returns to Home
- Profile avatar → Profile Screen (to be built)

**Sub-screens**:
- `ChatConversationScreen`: Individual conversation view
- `ArchivedChatsScreen`: Archived conversations list
- `ChatProfileScreen`: Profile view within chat context
- `VoiceRecordingScreen`: Voice message recording

### 3. Profile Tab (`lib/screens/profile_screen.dart`)
**Status**: ❌ Not Built (To be implemented)

**Main Screen Structure** (Based on Figma):
1. **Header**
   - "Profile" title
   - Search icon (right side)
   - Status bar (iPhone style)

2. **Profile Section**
   - Profile avatar/photo (large circle)
   - "Edit Photo" button overlay
   - Decorative ellipse background

3. **Upgrade to Pro Section**
   - Card with Edit icon
   - "Upgrade to Pro" title
   - "Unlock premium reserved just for YOU." subtitle

4. **General Section**
   - **Edit bio** (with edit icon) → Navigates to `EditBioScreen`
   - **Sexual Orientation** (with edit icon)
     - Displays: Gay, Aromantic, Bisexual, Asexual
     - Edit icon → Navigates to `SexualOrientationScreen` (already exists)
   - **Interest** (with edit icon)
     - Displays interest tags (Pole Dance, Anime, Rugby, Sports, K-dramas, Fitness, Thrillers, Movie)
     - Edit icon → Navigates to `InterestsScreen` (already exists)

5. **Support Section**
   - **Help center** → Navigates to `HelpCenterScreen`

6. **About Section**
   - **Rate SeaYou** → Opens `RateSeaYouModal`
   - **Terms of Service** → Opens Terms of Service page
   - **Privacy Policy** → Opens Privacy Policy page

7. **Account Actions**
   - **Sign Out** → Opens `SignOutModal`
   - **Delete account** → Opens `DeleteAccountModal`

8. **Bottom Navigation Bar**
   - Home, Chat, Profile (Profile active)

**Profile Sub-screens to Build**:

#### a. Edit Bio Screen (`lib/screens/profile/edit_bio_screen.dart`)
- Header with back arrow and "Edit bio" title
- Email Address input field
- Technical Issue text area
- "Send" button (disabled until fields filled)
- Status bar

#### b. Help Center Screen (`lib/screens/profile/help_center_screen.dart`)
- Header with back arrow and "Help Center" title
- Email Address input field
- Technical Issue description text area
- "Send" button (disabled until fields filled)
- Status bar

#### c. Rate SeaYou Modal (`lib/widgets/rate_seayou_modal.dart`)
- Modal overlay
- "Rate SeaYou" title
- "Rate your experience with SeaYou." subtitle
- Star rating component
- Text input: "Describe your experience with SeaYou"
- "Rate" button (disabled until rating selected)

#### d. Sign Out Modal (`lib/widgets/sign_out_modal.dart`)
- Modal overlay
- Log out icon
- "Sign Out of SeaYou" title
- "You can always sign in at anytime with your login details." subtitle
- "Close" button (disabled style)
- "Sign Out" button (active style)

#### e. Delete Account Modal (`lib/widgets/delete_account_modal.dart`)
- Similar structure to Sign Out modal
- "Delete Account" title
- Warning message
- "Close" and "Delete" buttons

## Screen Navigation Map

```
Main App Entry
└── HomeScreen (default)
    ├── ReceivedBottlesViewer
    ├── BottleDetailScreen
    ├── AllBottlesScreen
    ├── SendBottleScreen
    ├── VoiceChatModal (dialog)
    ├── PhotoStampModal (dialog)
    ├── ChatScreen
    │   ├── ChatListScreen
    │   │   ├── ChatConversationScreen
    │   │   └── ArchivedChatsScreen
    │   └── ChatProfileScreen
    └── ProfileScreen (to be built)
        ├── EditBioScreen
        ├── HelpCenterScreen
        ├── SexualOrientationScreen (exists)
        ├── InterestsScreen (exists)
        ├── RateSeaYouModal (dialog)
        ├── SignOutModal (dialog)
        └── DeleteAccountModal (dialog)
```

## Design System

### Colors
- Primary: `#0AC5C5` (Cyan/Turquoise)
- White: `#FFFFFF`
- Black: `#151515`
- Grey: `#737373`
- Light Grey: `#E3E3E3`
- Dark Grey: `#363636`
- Background: `#F8F8F8`
- Error: `#FB3748`

### Typography
- Font Family: `Montserrat` (primary), `Inter` (navigation labels)
- Body Text: 16px, FontWeight.w500
- Label Text: 14px, FontWeight.w400
- Display Text: 20px, FontWeight.w500

### Icons
- Location: `assets/icons/`
- Format: SVG
- Common icons:
  - `home_simple.svg`
  - `chat_lines.svg`
  - `arrow_left.svg`
  - `search.svg`
  - `camera.svg`
  - `plus.svg`
  - `nav_arrow_down.svg`

### Images
- Location: `assets/images/`
- Profile avatar: `profile_avatar.png`
- Hero image: `hero_image.png`
- Background: `warm-gradiant.jpeg`

## Background System
- **WarmGradientBackground**: Used on Home and Chat screens
- Gradient colors: Peach to Purple tones
- Creates warm, welcoming atmosphere

## Current Implementation Status

### ✅ Completed
- Home Screen with all features
- Chat Screen with conversation list
- Chat conversation view
- Archived chats
- Send bottle functionality
- Bottle detail views
- Voice and photo modals
- Onboarding flow (splash, language, account creation, etc.)
- Profile info screen (onboarding)
- Sexual orientation screen
- Interests screen

### ❌ To Be Built
- **Profile Tab** (Main screen)
- Edit Bio Screen
- Help Center Screen
- Rate SeaYou Modal
- Sign Out Modal
- Delete Account Modal
- Integration of Profile tab into navigation

## Navigation Pattern
- Uses `Navigator.push()` for screen transitions
- Uses `Navigator.pop()` for going back
- Modals use `showDialog()` with custom dialog widgets
- Bottom navigation is consistent across all main screens
- Each main screen (Home, Chat, Profile) has its own navigation bar implementation

## Next Steps
1. Build Profile Screen main view
2. Build all Profile sub-screens and modals
3. Integrate Profile tab into Home and Chat navigation
4. Ensure consistent styling with existing screens
5. Test all navigation flows

