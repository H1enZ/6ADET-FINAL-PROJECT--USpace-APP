-- =============================================================================
-- 012: Mood set for the redesigned Home screen
--
-- The new Home offers exactly eight moods: Loved, Happy, Calm, Emotional,
-- Need a Hug, Flirty, Romantic and Excited. Five of them are new to the
-- database, so the check on moods.mood now also allows:
--   calm, emotional, need_a_hug, flirty, romantic
--
-- Every earlier value stays allowed, so existing history keeps working
-- (relaxed, tired, stressed, sad, anxious, lonely and upset are no longer
-- offered by the app, but old check-ins with them remain valid and readable).
--
-- Only this one check constraint changes. No table, column, policy,
-- trigger or function is touched.
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run.
-- Safe to run more than once.
-- =============================================================================

alter table public.moods drop constraint if exists moods_mood_check;
alter table public.moods add constraint moods_mood_check check (mood in (
  -- Offered by the app (the eight Home moods)
  'loved', 'happy', 'calm', 'emotional', 'need_a_hug', 'flirty', 'romantic', 'excited',
  -- History only: allowed so older check-ins stay valid
  'relaxed', 'tired', 'stressed', 'sad', 'anxious', 'lonely', 'upset'
));
