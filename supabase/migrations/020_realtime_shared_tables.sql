-- =============================================================================
-- 020: Live updates for the rest of the shared space
--
-- Adds the remaining shared tables to Supabase Realtime, so a change one
-- partner makes appears on the other's phone without refreshing:
--
--   * memories, memory_photos        Timeline and memory details
--   * bucket_items,
--     bucket_contributions           Bucket list and savings
--   * important_dates                Special dates and the Home countdown
--   * question_answers               Today's question
--   * moods                          Home mood card and mood history
--   * profiles, couples              names, photos, birthdays, anniversary
--
-- Nothing about who can see what changes. Realtime sends a row only to
-- someone the table's existing row-level security already lets read it:
-- a mood only when it is shared, a question answer only once you have
-- answered too, everything else only within your own couple.
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run.
-- Safe to run more than once. Needs 001 to 019.
-- =============================================================================

do $rt$
declare t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array[
      'memories', 'memory_photos',
      'bucket_items', 'bucket_contributions',
      'important_dates', 'question_answers', 'moods',
      'profiles', 'couples'
    ] loop
      if not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime'
                       and schemaname = 'public' and tablename = t) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end;
$rt$;
