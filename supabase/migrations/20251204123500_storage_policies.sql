-- Storage policies for buckets: avatars, gallery_photos, content_images (public read), face_photos (private)
-- Note: Buckets are created via Supabase dashboard/CLI; this file defines policies on storage.objects only.

-- Public read for selected buckets
CREATE POLICY storage_public_read ON storage.objects
  FOR SELECT
  USING (bucket_id IN ('avatars','gallery_photos','content_images'));

-- Owner can insert/update/delete under their own prefix: auth.uid()/...
CREATE POLICY storage_owner_write ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    name LIKE auth.uid() || '/%'
  );

CREATE POLICY storage_owner_update ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (name LIKE auth.uid() || '/%')
  WITH CHECK (name LIKE auth.uid() || '/%');

CREATE POLICY storage_owner_delete ON storage.objects
  FOR DELETE
  TO authenticated
  USING (name LIKE auth.uid() || '/%');

-- Prevent public read of face_photos
CREATE POLICY storage_face_private_read ON storage.objects
  FOR SELECT
  USING (bucket_id <> 'face_photos');

-- Allow owners to read their own face photos
CREATE POLICY storage_face_owner_read ON storage.objects
  FOR SELECT
  TO authenticated
  USING (bucket_id = 'face_photos' AND name LIKE auth.uid() || '/%');
