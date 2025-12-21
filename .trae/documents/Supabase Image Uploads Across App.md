## Current Upload Requirements
- Profile face photo: `lib/screens/upload_picture_screen.dart` uses `ImagePicker` and writes to `face_photos` via `DatabaseService.uploadFirstFacePhotoAndInsert` (lib/services/database_service.dart:834–868); displayed in profiles (`profiles.face_photo_url`).
- Gallery photos: `DatabaseService.uploadGalleryPhoto` stores to `gallery_photos` and inserts `profile_photos` (lib/services/database_service.dart:793–813); visibility managed in `ManageGalleryPhotosScreen` (toggles via `setPhotoGalleryVisibility`).
- Avatars: `DatabaseService.uploadAvatar` writes to `avatars` (lib/services/database_service.dart:74–94); currently not wired in UI.
- Send bottle photo: picker exists in `lib/screens/send_bottle_screen.dart` (UI) but upload to storage is not implemented; uses placeholder `photo_url` in bottle send.
- Chat attachments: image picker in `lib/screens/chat/chat_conversation_screen.dart` (`_takePhoto`, `_chooseFromGallery`) attaches local `imagePath` without storage upload.
- Secret Souls: reads `profile_photos` via `getSecretSoulsPhotos` and displays with `Image.network` (lib/screens/secret_souls_gallery_screen.dart:65–86).

## Standardized Upload Architecture
- Create `UploadService` to unify all image operations with:
  - `pickImage({source: camera|gallery, maxWidth, maxHeight, quality})`
  - `uploadImage({bucket, userId, file, entityType, entityId, visibility, onProgress})`
  - `makePublicUrl({bucket, path})`, `makeSignedUrl({bucket, path, expires})`
  - `deleteImage({bucket, path})`, `updateMetadata({imageId, ...})`
- Buckets mapping:
  - `face_photos` (private, signed URLs) for mandatory confidential face photo
  - `gallery_photos` (public read, owner write) for Secret Souls/gallery
  - `avatars` (public read, owner write) for lightweight profile avatar
  - `content_images` (public read, owner write) for bottle/chat attachments
- File naming convention: `userId/<prefix>_<epochMillis>.<ext>`; prefix values: `face`, `gallery`, `avatar`, `content`. Cache-control `3600` and `upsert: false` for all uploads.
- Progress: `UploadService` exposes a `Stream<UploadProgress>` (start → bytesSent/total → completion/failure); UI subscribes to show progress bars.

## Supabase Storage Configuration
- Buckets:
  - Create `face_photos` (private), `gallery_photos` (public), `avatars` (public), `content_images` (public).
- Policies (storage.objects):
  - Insert: only authenticated users can upload to buckets; `user_id = auth.uid()` in object metadata or path prefix check (`path LIKE 'auth.uid()/%'`).
  - Select:
    - `face_photos`: only object owner and authorized reveal workflows (via signed URL); no public read.
    - `gallery_photos`, `avatars`, `content_images`: public read, owner update/delete.
  - Update/Delete: only owner by path prefix (`(bucket_id = '...' AND (name LIKE auth.uid() || '/%'))`).
- Performance:
  - Enable CDN; set `cacheControl` on objects; encourage client-side compression (e.g., JPG/WebP quality 80–85).

## Database Integration
- Tables (new or confirm existing):
  - `images` (id uuid PK, owner_id uuid FK profiles(id), bucket text, path text, url text, content_type text, size int, width int, height int, entity_type text, entity_id uuid, visibility text, created_at timestamptz, updated_at timestamptz).
  - Relationships: `entity_type ∈ {'profile_photo','avatar','message_attachment','bottle_photo'}` with `entity_id` referencing `profile_photos.id`, `messages.id`, `sent_bottles.id` respectively (FK with `ON DELETE CASCADE`).
  - Confirm or add `profile_photos` fields (`is_face`, `is_first_face_photo`, `ai_face_score`, `is_hidden`, `is_visible_in_secret_souls`), already used by `DatabaseService.setPhotoFlags`.
- Triggers:
  - On `messages` insert with attachment image, create an `images` row; keep attachment URLs consistent.
  - Enforce one `is_first_face_photo = TRUE` per user with trigger (existing in `20251203210000_face_verify.sql`).

## Error Handling Strategy
- Selection errors: catch `ImagePicker` exceptions, show actionable messages.
- Upload interruptions: wrap uploads with retry (exponential backoff x3), cancel support; surface partial progress.
- Quota limits: handle `PostgrestException`/HTTP 413 or storage error codes; show user-friendly guidance and prevent retry storm.
- Connectivity: detect offline before starting uploads; queue items and auto-retry when back online.

## State Management
- `UploadController` (ChangeNotifier) to track:
  - Pending, in-progress, completed, failed uploads
  - Per-item progress and overall queue
  - Concurrency limit (e.g., 3 simultaneous uploads with FIFO queue)
- UI hooks: callbacks for progress; disable actions while uploading large files; keep screens responsive with `FutureBuilder` or subscription.

## Implementation Roadmap
1. Build `UploadService` and `UploadController` with unified APIs and progress callback.
2. Wire UI:
   - UploadPictureScreen → use `UploadService.uploadImage(bucket: face_photos)`; keep verification step.
   - ManageGalleryPhotosScreen → add “Add Photo” button using `gallery_photos` and metadata insert.
   - SendBottleScreen → replace placeholder with real `content_images` upload and store `photo_url` in sent/received bottles.
   - ChatConversationScreen → upload selected/taken images to `content_images`; store attachment in `messages.media_url` and create `images` metadata.
3. Storage policies creation for buckets and owner-based access.
4. DB migrations for `images` table and necessary FKs; add indices on `(owner_id, entity_type, entity_id)`.

## Testing
- Unit: mock `SupabaseClient.storage` and test naming, error mapping, retry logic, progress events.
- Integration: run against test Supabase project or local; verify upload succeeds and metadata rows created; assert policies.
- UI: widget tests for pickers and progress UI; chat/send bottle flows with attachment uploads.
- Performance: test large file (e.g., 5–10 MB) upload timing; ensure UI remains responsive; validate retry on simulated network drops.

## Supabase Best Practices
- Use path-based ownership (`auth.uid()/...`).
- Prefer signed URLs for private content (`face_photos`), public URLs for gallery content.
- Avoid service role keys client-side; call edge functions for privileged actions.
- Cache-control headers and CDN enabled; compress images client-side.

## Documentation
- Add `docs/upload.md`:
  - API reference (UploadService methods, parameters)
  - Usage examples for face, gallery, bottle, chat
  - Troubleshooting: picker permissions, offline, quota, retries, signed URL expiry
  - Storage/bucket structure and policies summary

## Notes & Code References
- Existing storage code in `lib/services/database_service.dart:74–94, 793–813, 815–868` and UI pickers in `lib/screens/upload_picture_screen.dart`, `lib/screens/send_bottle_screen.dart`, `lib/screens/chat/chat_conversation_screen.dart` will be refactored to use `UploadService`.
- Secret Souls gallery displays from `profile_photos`; add upload entry point in manage screen to complete flow.

Confirm and I’ll implement UploadService, bucket policies/migrations, UI wiring, tests, and docs step-by-step.