-- =============================================================================
-- 013: USpace chat reactions
--
-- Chat now offers eleven custom reactions. They are stored as plain text
-- keys, so the check on message_reactions.emoji now also allows:
--   love, in_love, laugh, hug, kiss, puppy_eyes,
--   aww, sad, upset, here_for_you, proud_of_you
--
-- The six original emoji values stay allowed, so every existing reaction
-- stays valid and readable. The app no longer writes them; nothing stored
-- is changed or converted.
--
-- Only this one check constraint changes. No column, key, policy, trigger,
-- realtime setting or function is touched, and it is still one reaction per
-- person per message.
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run.
-- Safe to run more than once.
-- =============================================================================

alter table public.message_reactions drop constraint if exists message_reactions_emoji_check;
alter table public.message_reactions add constraint message_reactions_emoji_check check (emoji in (
  -- Offered by the app (quick reactions, then "More")
  'love', 'in_love', 'laugh', 'hug', 'kiss', 'puppy_eyes',
  'aww', 'sad', 'upset', 'here_for_you', 'proud_of_you',
  -- Original reactions: allowed so existing ones stay valid
  '❤️', '😂', '😮', '😢', '🥰', '👍'
));
