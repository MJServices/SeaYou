-- We skip the ALTER TABLE as it requires ownership and is usually already enabled.
-- We focusing on creating the policies.

-- 1. Ensure bucket exists
INSERT INTO storage.buckets (id, name, public) 
VALUES ('face_photos', 'face_photos', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Create policies. We wrap in a DO block to safely drop if exists (though standard DROP IF EXISTS should work, we'll keep it simple).

-- Allow public read access (essential for viewing the photo)
DROP POLICY IF EXISTS "Public Select face_photos" ON storage.objects;
CREATE POLICY "Public Select face_photos"
ON storage.objects FOR SELECT
USING ( bucket_id = 'face_photos' );

-- Allow authenticated users to upload
DROP POLICY IF EXISTS "Authenticated Insert face_photos" ON storage.objects;
CREATE POLICY "Authenticated Insert face_photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK ( bucket_id = 'face_photos' );

-- Allow users to update their own files
DROP POLICY IF EXISTS "Users update own face_photos" ON storage.objects;
CREATE POLICY "Users update own face_photos"
ON storage.objects FOR UPDATE
TO authenticated
USING ( bucket_id = 'face_photos' AND auth.uid() = owner )
WITH CHECK ( bucket_id = 'face_photos' AND auth.uid() = owner );

-- Allow users to delete their own files
DROP POLICY IF EXISTS "Users delete own face_photos" ON storage.objects;
CREATE POLICY "Users delete own face_photos"
ON storage.objects FOR DELETE
TO authenticated
USING ( bucket_id = 'face_photos' AND auth.uid() = owner );
