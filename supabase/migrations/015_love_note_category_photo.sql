-- =============================================================================
-- 015: Love Note categories and an optional photo
--
-- The Love Notes redesign gives each note a type (Just Because, Thank You,
-- Missing You, Proud of You, Love) and up to one photo. Both columns are
-- optional, so older notes keep working and show under "All".
--
--   * category    one of five keys, or null for older notes
--   * photo_path  a file in the private memory-photos bucket, stored as
--                 <couple_id>/notes/<file>. The bucket's existing couple-only
--                 read / upload / delete rules already cover that folder.
--
-- A regular note's title reuses capsule_title (the app caps it at 40).
-- Permissions are unchanged: the author inserts and deletes, and either
-- partner can only change is_favorite.
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run ONCE.
-- =============================================================================

alter table public.notes
  add column category text
    check (category is null or category in
      ('just_because', 'thank_you', 'missing_you', 'proud_of_you', 'love')),
  add column photo_path text
    check (photo_path is null or char_length(photo_path) between 1 and 300);
