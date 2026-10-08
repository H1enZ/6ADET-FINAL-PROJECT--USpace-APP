-- =============================================================================
-- 021: Private Realtime channels for each couple
--
-- The app's live updates use two Realtime channels per couple:
--
--   * couple-<couple id>         table changes, plus "changed" broadcasts
--                                (an empty signal naming a table, sent after
--                                a delete so the partner re-reads it)
--   * couple-shared-<couple id>  table changes only (the tables from 020)
--
-- Until now these were public channels: anyone who knew a couple's id could
-- join, hear the "changed" signals and send fake ones. Table rows were never
-- exposed (each table's row-level security still decides who receives what),
-- but the signals and the ability to inject them were.
--
-- These policies let the app use PRIVATE channels instead. A private channel
-- is only joined, and only accepts broadcasts, when the policies below allow
-- it, and the allowed topics come from the signed-in user's own couple in the
-- database (my_couple_id()), never from anything the app sends. A user with
-- no couple gets no topic; signed-out visitors (anon) get nothing.
--
-- Public channels are not affected by these policies, so app versions that
-- still use public channels keep working until they are updated.
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run.
-- Safe to run more than once. Needs 001 to 020.
-- =============================================================================

-- Listen: join (and receive on) your own couple's two channels only.
drop policy if exists "realtime: couple members listen" on realtime.messages;
create policy "realtime: couple members listen" on realtime.messages
  for select to authenticated
  using (
    realtime.topic() = any (array[
      'couple-' || public.my_couple_id()::text,
      'couple-shared-' || public.my_couple_id()::text
    ])
  );

-- Send: broadcast to your own couple's main channel only. (The shared
-- channel carries table changes, never broadcasts.)
drop policy if exists "realtime: couple members send" on realtime.messages;
create policy "realtime: couple members send" on realtime.messages
  for insert to authenticated
  with check (
    realtime.messages.extension = 'broadcast'
    and realtime.topic() = 'couple-' || public.my_couple_id()::text
  );
