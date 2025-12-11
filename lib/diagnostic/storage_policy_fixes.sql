-- =====================================================
-- STORAGE POLICY FIXES
-- Cleanup duplicate policies and add missing policies
-- Generated: December 11, 2025
-- =====================================================

-- =====================================================
-- STEP 1: REMOVE DUPLICATE POLICIES
-- =====================================================

-- Remove duplicate clips policies (keep the newer named versions)
DROP POLICY IF EXISTS "Public can view clips" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own clips" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload clips" ON storage.objects;

-- Remove duplicate media policies
DROP POLICY IF EXISTS "Users can upload media" ON storage.objects;

-- Remove conflicting media public read policy (bucket is configured as private)
DROP POLICY IF EXISTS "media_public_read" ON storage.objects;

-- =====================================================
-- STEP 2: ADD MISSING AVATAR POLICIES
-- =====================================================

-- Add missing DELETE policy for avatars
CREATE POLICY "avatars_owner_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars' AND 
    (storage.foldername(name))[1] = (auth.uid())::text
  );

-- =====================================================
-- STEP 3: ENHANCE EXISTING POLICIES WITH FOLDER RESTRICTIONS
-- =====================================================

-- Drop and recreate upload policies with folder restrictions
DROP POLICY IF EXISTS "Users can upload avatars" ON storage.objects;
CREATE POLICY "avatars_owner_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars' AND 
    (storage.foldername(name))[1] = (auth.uid())::text
  );

DROP POLICY IF EXISTS "clips_authenticated_upload" ON storage.objects;
CREATE POLICY "clips_owner_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'clips' AND 
    (storage.foldername(name))[1] = (auth.uid())::text
  );

DROP POLICY IF EXISTS "media_authenticated_upload" ON storage.objects;
CREATE POLICY "media_owner_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'media' AND 
    (storage.foldername(name))[1] = (auth.uid())::text
  );

-- =====================================================
-- STEP 4: ADD MISSING POLICIES FOR CHAT_BACKGROUNDS
-- =====================================================

-- Public read access
CREATE POLICY "chat_backgrounds_public_read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'chat_backgrounds');

-- Authenticated users can upload to their own folder
CREATE POLICY "chat_backgrounds_owner_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'chat_backgrounds' AND 
    (storage.foldername(name))[1] = (auth.uid())::text
  );

-- Owner-only update
CREATE POLICY "chat_backgrounds_owner_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'chat_backgrounds' AND 
    (storage.foldername(name))[1] = (auth.uid())::text
  );

-- Owner-only delete
CREATE POLICY "chat_backgrounds_owner_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'chat_backgrounds' AND 
    (storage.foldername(name))[1] = (auth.uid())::text
  );

-- =====================================================
-- STEP 5: ADD MISSING POLICIES FOR SQUADSYNC-MEDIA
-- =====================================================

-- Public read access
CREATE POLICY "squadsync_media_public_read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'squadsync-media');

-- Authenticated users can upload to their own folder
CREATE POLICY "squadsync_media_owner_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'squadsync-media' AND 
    (storage.foldername(name))[1] = (auth.uid())::text
  );

-- Owner-only update
CREATE POLICY "squadsync_media_owner_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'squadsync-media' AND 
    (storage.foldername(name))[1] = (auth.uid())::text
  );

-- Owner-only delete
CREATE POLICY "squadsync_media_owner_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'squadsync-media' AND 
    (storage.foldername(name))[1] = (auth.uid())::text
  );

-- =====================================================
-- STEP 6: UPDATE BUCKET CONFIGURATIONS (OPTIONAL)
-- =====================================================

-- Add file size limits (in bytes)
UPDATE storage.buckets SET file_size_limit = 5242880 WHERE id = 'avatars'; -- 5 MB
UPDATE storage.buckets SET file_size_limit = 10485760 WHERE id = 'chat_backgrounds'; -- 10 MB
UPDATE storage.buckets SET file_size_limit = 524288000 WHERE id = 'clips'; -- 500 MB
UPDATE storage.buckets SET file_size_limit = 52428800 WHERE id = 'media'; -- 50 MB
UPDATE storage.buckets SET file_size_limit = 104857600 WHERE id = 'squadsync-media'; -- 100 MB

-- Add MIME type restrictions
UPDATE storage.buckets 
SET allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/avif']
WHERE id = 'avatars';

UPDATE storage.buckets 
SET allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/avif']
WHERE id = 'chat_backgrounds';

UPDATE storage.buckets 
SET allowed_mime_types = ARRAY['video/mp4', 'video/webm', 'video/ogg', 'video/quicktime']
WHERE id = 'clips';

UPDATE storage.buckets 
SET allowed_mime_types = ARRAY[
  'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/avif',
  'video/mp4', 'video/webm', 'video/ogg',
  'audio/mpeg', 'audio/ogg', 'audio/wav',
  'application/pdf'
]
WHERE id = 'media';

UPDATE storage.buckets 
SET allowed_mime_types = ARRAY[
  'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/avif',
  'video/mp4', 'video/webm', 'video/ogg',
  'audio/mpeg', 'audio/ogg', 'audio/wav'
]
WHERE id = 'squadsync-media';

-- Enable AVIF detection for image buckets
UPDATE storage.buckets SET avif_autodetection = true WHERE id = 'avatars';
UPDATE storage.buckets SET avif_autodetection = true WHERE id = 'chat_backgrounds';
UPDATE storage.buckets SET avif_autodetection = true WHERE id = 'squadsync-media';

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check all storage policies after changes
SELECT 
    policyname,
    cmd as command,
    roles,
    qual as using_expression
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects'
ORDER BY policyname;

-- Check bucket configurations
SELECT 
    id,
    name,
    public,
    file_size_limit,
    pg_size_pretty(file_size_limit::bigint) as size_limit_pretty,
    allowed_mime_types,
    avif_autodetection
FROM storage.buckets
ORDER BY name;

-- Count policies per bucket
SELECT 
    SUBSTRING(policyname FROM '^[a-z_]+') as bucket,
    COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects'
GROUP BY SUBSTRING(policyname FROM '^[a-z_]+')
ORDER BY bucket;

-- =====================================================
-- SUMMARY OF CHANGES
-- =====================================================
/*
POLICIES REMOVED (5):
1. "Public can view clips" - duplicate of clips_public_read
2. "Users can delete own clips" - duplicate of clips_owner_delete
3. "Users can upload clips" - duplicate of clips_authenticated_upload
4. "Users can upload media" - duplicate of media_authenticated_upload
5. "media_public_read" - conflicted with private bucket config

POLICIES REPLACED (3):
1. "Users can upload avatars" → "avatars_owner_upload" (with folder restriction)
2. "clips_authenticated_upload" → "clips_owner_upload" (with folder restriction)
3. "media_authenticated_upload" → "media_owner_upload" (with folder restriction)

POLICIES ADDED (9):
1. "avatars_owner_delete" - missing DELETE policy for avatars
2. "chat_backgrounds_public_read" - public SELECT
3. "chat_backgrounds_owner_upload" - authenticated INSERT with folder check
4. "chat_backgrounds_owner_update" - owner UPDATE
5. "chat_backgrounds_owner_delete" - owner DELETE
6. "squadsync_media_public_read" - public SELECT
7. "squadsync_media_owner_upload" - authenticated INSERT with folder check
8. "squadsync_media_owner_update" - owner UPDATE
9. "squadsync_media_owner_delete" - owner DELETE

BUCKET CONFIGURATIONS UPDATED (5):
- All buckets now have file size limits (5MB to 500MB)
- All buckets now have MIME type restrictions
- Image buckets (avatars, chat_backgrounds, squadsync-media) have AVIF detection enabled

FINAL POLICY COUNT:
- Before: 16 policies (12 unique + 4 duplicates), covering 3/5 buckets
- After: 20 policies (all unique), covering 5/5 buckets

SECURITY IMPROVEMENTS:
✅ Removed duplicate policies for cleaner policy set
✅ Fixed media bucket public access contradiction
✅ Added folder-based upload restrictions (users can only upload to own folders)
✅ Added missing DELETE policy for avatars
✅ Added complete policy sets for chat_backgrounds and squadsync-media
✅ Added file size limits to prevent abuse
✅ Added MIME type restrictions to prevent malicious uploads
✅ Enabled AVIF support for image buckets
*/
