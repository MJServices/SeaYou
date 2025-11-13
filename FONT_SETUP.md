# Font Setup Instructions

## Required Fonts

The SeaYou app uses the **Montserrat** font family. You need to download and add the following font files:

- Montserrat-Regular.ttf
- Montserrat-Medium.ttf
- Montserrat-SemiBold.ttf

## Step-by-Step Instructions

### Step 1: Download Montserrat Font

1. Go to Google Fonts: https://fonts.google.com/specimen/Montserrat
2. Click the "Download family" button (top right)
3. A ZIP file will be downloaded

### Step 2: Extract the ZIP File

1. Locate the downloaded file (usually in Downloads folder)
2. Extract/Unzip the file
3. You'll see a folder with many .ttf files

### Step 3: Find the Required Files

Look for these specific files in the extracted folder:

```
Montserrat/
├── static/
│   ├── Montserrat-Regular.ttf      ← Copy this
│   ├── Montserrat-Medium.ttf       ← Copy this
│   └── Montserrat-SemiBold.ttf     ← Copy this
```

**Note**: The files might be in a "static" subfolder.

### Step 4: Copy Files to Project

1. Navigate to your project folder: `seayou_app/`
2. Go to: `assets/fonts/`
3. Copy the 3 font files into this folder

Your folder structure should look like:

```
seayou_app/
├── assets/
│   └── fonts/
│       ├── Montserrat-Regular.ttf
│       ├── Montserrat-Medium.ttf
│       └── Montserrat-SemiBold.ttf
```

### Step 5: Verify Configuration

The `pubspec.yaml` file is already configured with:

```yaml
fonts:
  - family: Montserrat
    fonts:
      - asset: assets/fonts/Montserrat-Regular.ttf
      - asset: assets/fonts/Montserrat-Medium.ttf
        weight: 500
      - asset: assets/fonts/Montserrat-SemiBold.ttf
        weight: 600
```

### Step 6: Reload the App

If the app is already running:

1. Stop the app
2. Run `flutter clean`
3. Run `flutter pub get`
4. Run `flutter run`

## Troubleshooting

### Problem: Fonts not showing correctly

**Solution 1**: Check file names

- Make sure the file names match exactly (case-sensitive)
- No extra spaces or characters

**Solution 2**: Check file location

- Files must be in `assets/fonts/` folder
- Not in any subfolder

**Solution 3**: Clean and rebuild

```bash
flutter clean
flutter pub get
flutter run
```

### Problem: "Unable to load asset" error

**Solution**:

1. Check that the font files exist in the correct location
2. Verify the paths in `pubspec.yaml` match the actual file locations
3. Make sure there are no typos in the file names

### Problem: Text looks different than expected

**Solution**:

- Make sure you downloaded the correct font (Montserrat, not Montserrat Alternates)
- Verify you have all three weights (Regular, Medium, SemiBold)

## Alternative: Using System Fonts (Temporary)

If you can't download the fonts right now, you can temporarily use system fonts:

1. Open `lib/utils/app_text_styles.dart`
2. Change `fontFamily: 'Montserrat'` to `fontFamily: 'Roboto'` (or remove it)
3. The app will use the default system font

**Note**: This is only for testing. The final app should use Montserrat.

## Font Weights Used in App

- **Regular (400)**: Label text, body text in some places
- **Medium (500)**: Most body text, display text
- **SemiBold (600)**: Large titles, medium titles

## File Sizes

Approximate sizes:

- Montserrat-Regular.ttf: ~200 KB
- Montserrat-Medium.ttf: ~200 KB
- Montserrat-SemiBold.ttf: ~200 KB

Total: ~600 KB

## License

Montserrat is licensed under the SIL Open Font License (OFL).
You can use it freely in your projects.

## Additional Resources

- Google Fonts: https://fonts.google.com/specimen/Montserrat
- Font License: https://scripts.sil.org/OFL
- Flutter Font Documentation: https://flutter.dev/docs/cookbook/design/fonts

## Quick Check

After adding fonts, verify they're working:

1. Run the app
2. Look at the splash screen
3. The text should appear in Montserrat font
4. If it looks like the default system font, fonts aren't loaded correctly

## Need Help?

If you're still having issues:

1. Check the Flutter console for error messages
2. Verify file paths are correct
3. Make sure you ran `flutter pub get` after adding fonts
4. Try `flutter clean` and rebuild

---

**Remember**: The app won't look exactly right without the Montserrat fonts, so make sure to add them before testing!
