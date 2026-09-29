-- =============================================================================
-- 005: photo upload limits enforced by Storage itself
--
-- The app already refuses photos over 5 MB and non-image files, but that check
-- runs in the browser and could be skipped by calling the API directly.
-- These limits make Supabase Storage reject them on the server too.
--
-- Safe to run more than once. Supabase > SQL Editor > New query > Run.
-- =============================================================================

update storage.buckets
   set file_size_limit = 5242880,  -- 5 MB
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
 where id = 'memory-photos';

update storage.buckets
   set file_size_limit = 5242880,
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
 where id = 'avatars';

-- Check: both rows should show public = false, 5242880, and the image types.
select id, public, file_size_limit, allowed_mime_types
  from storage.buckets
 order by id;
