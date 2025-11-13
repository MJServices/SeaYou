# Image Picker Setup Instructions

The upload picture functionality is now working! Users can:

- Pick images from their gallery
- Take photos with the camera
- See the selected image displayed in the circular avatar

## Platform-Specific Setup Required

### For Android (android/app/src/main/AndroidManifest.xml)

Add these permissions inside the `<manifest>` tag:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

### For iOS (ios/Runner/Info.plist)

Add these keys inside the `<dict>` tag:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to upload profile pictures</string>
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take profile pictures</string>
<key>NSMicrophoneUsageDescription</key>
<string>We need access to your microphone for video recording</string>
```

## Features Implemented

1. **Upload from Gallery**: Opens device gallery to select existing photos
2. **Take Photo**: Opens camera to take a new photo
3. **Image Preview**: Selected image displays in the circular avatar
4. **Tap to Change**: Users can tap the avatar circle to pick a new image
5. **Image Optimization**: Images are automatically resized to 1080x1080 with 85% quality

## How It Works

- The screen is now stateful to manage the selected image
- Uses `image_picker` package (v1.1.2)
- Images are stored temporarily in memory (not persisted)
- When user navigates away, the image is just for UI preview
- Perfect for frontend development without backend storage

## Testing

1. Run the app: `flutter run`
2. Navigate to the Upload Picture screen
3. Click "Upload from gallery" to select from photos
4. Click "Take photo" to use the camera
5. Tap the circular avatar to change the image
6. Click "Skip" to proceed without uploading
