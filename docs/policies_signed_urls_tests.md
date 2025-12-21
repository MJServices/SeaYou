# Supabase Policies & Signed URL Tests

## Setup
- Create a test Supabase project.
- Set environment variables before running tests:
  - `TEST_SUPABASE_URL`
  - `TEST_SUPABASE_ANON_KEY`
  - `TEST_PUBLIC_OBJECT_PATH` (e.g., `content_images/<uid>/content_...jpg`)
  - `TEST_FACE_OBJECT_PATH` (e.g., `<uid>/face_...jpg` in `face_photos`)

## Tests
- Public buckets allow read without auth headers.
- `face_photos` requires signed URL; unsigned access returns 401/404.
- Signed URLs generated via client are valid for the expiry period.

## Methodology
- Uses `http` and `supabase_flutter` to exercise storage policies.
- Skips automatically if env is not provided.

## Known Limitations
- Requires real objects in buckets to validate.
- Does not cover table RLS; add similar tests for `profiles`, `profile_photos` as needed.

## Future Improvements
- Add CI job with ephemeral Supabase project.
- Extend tests to verify owner-only writes via path prefix.
