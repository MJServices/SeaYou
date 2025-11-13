# SeaYou App - Complete Flow Diagram

## Visual Navigation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        SPLASH SCREEN                             │
│  • Animated background with circles                             │
│  • Profile image placeholders                                   │
│  • Interest tags (K-dramas, Anime, Sports, You)                │
│  • "Get Started" button                                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   LANGUAGE SELECTION                             │
│  • English (device's language) ○                                │
│  • French ○                                                     │
│  • German ○                                                     │
│  • Spanish ○                                                    │
│  • [Continue] button                                            │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CREATE ACCOUNT                                │
│  • Email input: [e.g alexjohn@gmail.com]                       │
│  • Validation: Must contain @ and .                            │
│  • Terms acceptance text                                        │
│  • [Send verification code] button                             │
│  • "Already a member? Sign in" link                            │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                     VERIFICATION                                 │
│  ← Back                                                         │
│  • 6-digit code input: [1][1][1][_][_][_]                     │
│  • Auto-focus next field                                        │
│  • Resend code on 00:20                                         │
│  • [Verifying] button                                           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   CREATE PASSWORD                                │
│  ← Back                                                         │
│  • Password input: [••••••••] 👁                               │
│  • Requirements:                                                │
│    ✓ Minimum of 8 characters                                   │
│    ✓ At least a symbol                                         │
│    ✓ At least a number                                         │
│  • [Create Password] button                                     │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                  PROFILE INFO (1/5)                              │
│  • Full Name: [Enter your name]                                │
│  • Age: [Enter your age]                                        │
│  • City: [Nairobi ▼]                                           │
│  • About: [Add a short bio description]                        │
│    Character count: 0/80                                        │
│  • [Next] button                                                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              SEXUAL ORIENTATION (2/5)                            │
│  ← Back                                                         │
│  • Select all that apply:                                       │
│    □ Heterosexual                                               │
│    □ Gay                                                        │
│    □ Lesbian                                                    │
│    □ Bisexual                                                   │
│    □ Asexual                                                    │
│    □ Pansexual                                                  │
│    □ Aromantic                                                  │
│  • Custom input: [Input sexual orientation]                    │
│  • ☑ Show my sexual orientation on profile                     │
│  • [Next] button                                                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                  EXPECTATIONS (3/5)                              │
│  ← Back                                                         │
│  • What are you looking for?                                    │
│    ○ A serious relationship                                     │
│    ○ A casual relationship                                      │
│    ○ To make friends                                            │
│    ○ I do not really know yet                                   │
│                                                                 │
│  • Who do you want to meet?                                     │
│    ○ Men                                                        │
│    ○ Women                                                      │
│    ○ Non-binary                                                 │
│    ○ Everyone                                                   │
│  • [Next] button                                                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    INTERESTS (4/5)                               │
│  ← Back          Interests                          Skip        │
│  Select at least two                                            │
│                                                                 │
│  Movies & Series:                                               │
│  [K-dramas] [Bollywood] [Series] [Movies] ...                 │
│                                                                 │
│  Sports & Games:                                                │
│  [Football] [Basketball] [Olympics] ...                        │
│                                                                 │
│  Pets:                                                          │
│  [Cats] [Dogs] [Fish] [Allergic] ...                          │
│                                                                 │
│  Activities:                                                    │
│  [Shopping] [Karaoke] [Pubs] ...                              │
│                                                                 │
│  Creative:                                                      │
│  [Photography] [Tattoos] [Digital Art] ...                     │
│                                                                 │
│  Restaurants:                                                   │
│  [BBQ] [Brunch] [Ramen] [Tea] ...                             │
│                                                                 │
│  Meditation:                                                    │
│  [Bible Reading] [Therapy] [Walking] ...                       │
│                                                                 │
│  • [Next] button                                                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                 UPLOAD PICTURE (5/5)                             │
│  ← Back      Upload a picture                    Skip           │
│                                                                 │
│                    ┌─────────┐                                  │
│                    │    A    │  (300x300 circle)                │
│                    │         │                                  │
│                    └─────────┘                                  │
│                                                                 │
│  • [Upload from gallery] button                                │
│  • [Take photo] button (disabled)                              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                ACCOUNT SETUP DONE                                │
│  • "Your profile has been created!"                            │
│  • Animated bubbles background                                 │
│                                                                 │
│  How it works:                                                  │
│  📧 1. Send anonymous messages with mood tags                   │
│  📬 2. Receive messages (content + emotion only)                │
│  💕 3. Feeling bar activates after mutual replies               │
│  👤 4. Profile revealed when bar fills                          │
│                                                                 │
│  • Pro plan promotion text                                      │
│  • [Let's go!] button                                           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
                  [MAIN APP - Not Implemented]
```

## Screen-by-Screen Breakdown

### 1. Splash Screen

**Purpose**: Welcome & branding  
**Input**: None  
**Output**: User clicks "Get Started"  
**Validation**: None  
**Next**: Language Selection

### 2. Language Selection

**Purpose**: Choose app language  
**Input**: Radio button selection  
**Output**: Selected language  
**Validation**: Must select one  
**Next**: Create Account

### 3. Create Account

**Purpose**: Email registration  
**Input**: Email address  
**Output**: Email for verification  
**Validation**: Must contain @ and .  
**Next**: Verification

### 4. Verification

**Purpose**: Verify email ownership  
**Input**: 6-digit code  
**Output**: Verified email  
**Validation**: All 6 digits required  
**Next**: Create Password

### 5. Create Password

**Purpose**: Set secure password  
**Input**: Password string  
**Output**: Encrypted password  
**Validation**: 8+ chars, 1 symbol, 1 number  
**Next**: Profile Info

### 6. Profile Info (1/5)

**Purpose**: Basic user information  
**Input**: Name, Age, City, About  
**Output**: Profile data  
**Validation**: All fields required  
**Next**: Sexual Orientation

### 7. Sexual Orientation (2/5)

**Purpose**: Identity information  
**Input**: Multiple selections  
**Output**: Orientation list  
**Validation**: At least 1 selection  
**Next**: Expectations

### 8. Expectations (3/5)

**Purpose**: Dating preferences  
**Input**: Relationship type + Gender preference  
**Output**: Matching criteria  
**Validation**: 1 from each section  
**Next**: Interests

### 9. Interests (4/5)

**Purpose**: Hobby/interest matching  
**Input**: Multiple interest selections  
**Output**: Interest list  
**Validation**: Minimum 2 selections  
**Next**: Upload Picture

### 10. Upload Picture (5/5)

**Purpose**: Profile photo  
**Input**: Image file (optional)  
**Output**: Profile picture  
**Validation**: None (optional)  
**Next**: Account Setup Done

### 11. Account Setup Done

**Purpose**: Onboarding completion  
**Input**: None  
**Output**: User ready for main app  
**Validation**: None  
**Next**: Main App (not implemented)

## Data Flow

```
User Input → Validation → State Update → UI Update → Navigation
```

### Example: Create Account Screen

```
1. User types email
   ↓
2. onChange event fires
   ↓
3. Validation checks for @ and .
   ↓
4. setState updates isEmailValid
   ↓
5. Button color changes (grey → cyan)
   ↓
6. User clicks button
   ↓
7. Navigate to Verification screen
   ↓
8. Pass email as parameter
```

## State Management Pattern

Each screen follows this pattern:

```dart
class ScreenName extends StatefulWidget {
  @override
  State<ScreenName> createState() => _ScreenNameState();
}

class _ScreenNameState extends State<ScreenName> {
  // Controllers
  final TextEditingController _controller = TextEditingController();

  // State variables
  bool isValid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_validate);
  }

  void _validate() {
    setState(() {
      isValid = /* validation logic */;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          CustomTextField(
            controller: _controller,
            isActive: isValid,
          ),
          CustomButton(
            text: 'Next',
            isActive: isValid,
            onPressed: () => Navigator.push(...),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

## Navigation Pattern

```dart
// Forward navigation
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => NextScreen(data: data),
  ),
);

// Back navigation
Navigator.pop(context);

// Back button in AppBar
IconButton(
  icon: Icon(Icons.arrow_back),
  onPressed: () => Navigator.pop(context),
)
```

## Validation Summary

| Screen             | Field        | Validation Rule              |
| ------------------ | ------------ | ---------------------------- |
| Create Account     | Email        | Contains @ and .             |
| Verification       | Code         | 6 digits entered             |
| Create Password    | Password     | 8+ chars, 1 symbol, 1 number |
| Profile Info       | Name         | Not empty                    |
| Profile Info       | Age          | Not empty, numeric           |
| Profile Info       | City         | Not empty                    |
| Profile Info       | About        | Not empty, max 80 chars      |
| Sexual Orientation | Selection    | At least 1 selected          |
| Expectations       | Relationship | 1 selected                   |
| Expectations       | Gender       | 1 selected                   |
| Interests          | Interests    | At least 2 selected          |
| Upload Picture     | Image        | Optional                     |

## Progress Indicators

Screens 6-10 show progress:

- Profile Info: 1/5
- Sexual Orientation: 2/5
- Expectations: 3/5
- Interests: 4/5
- Upload Picture: 5/5

## Skip Options

- Interests screen: Skip button (top right)
- Upload Picture screen: Skip button (top right)

## Back Navigation

Available on:

- Verification
- Create Password
- Sexual Orientation
- Expectations
- Interests
- Upload Picture

Not available on:

- Splash Screen
- Language Selection
- Create Account
- Profile Info
- Account Setup Done

## Color Coding

- **Inactive state**: Grey (#737373)
- **Active state**: Cyan (#0AC5C5)
- **Disabled state**: Light Grey (#E3E3E3)
- **Error state**: Red (#FB3748)
- **Success state**: Green (checkmarks)

## Animation Opportunities

Current: Static screens  
Future enhancements:

- Fade transitions between screens
- Slide animations for navigation
- Bubble floating animation on splash/completion
- Progress bar animation
- Button press feedback
- Input field focus animation
- Chip selection animation

This flow represents the complete user journey through the SeaYou app onboarding process!
