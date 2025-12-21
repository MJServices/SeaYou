# Uploads and Storage

## Buckets
- face_photos (private)
- gallery_photos (public)
- avatars (public)
- content_images (public)

## Service API
- UploadService
  - pickFromGallery(maxWidth, maxHeight, quality)
  - pickFromCamera(maxWidth, maxHeight, quality)
  - uploadFile(bucket, userId, file, prefix)
  - buildPath(userId, prefix, ext)
- UploadController
  - enqueue(UploadTask)
  - statuses map for progress and results

## Usage
- SendBottle picture → content_images
- Chat attachments → content_images
- Manage Gallery → gallery_photos
- Upload Picture (face) → face_photos via DatabaseService

## Troubleshooting
- Picker errors: ensure permissions
- Upload failed: check connectivity and bucket policies
- Private access: use signed URLs for face photos

## Policies
- storage.objects public read: `avatars,gallery_photos,content_images`
- owner write via path prefix: `auth.uid()/...`
- `face_photos` private except owner
