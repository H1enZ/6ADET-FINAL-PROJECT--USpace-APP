-- =============================================================================
-- 007: Love Notes and Time Capsules
--
-- The notes table (from the first schema) already hides a sealed Time
-- Capsule from BOTH partners until unlock_at. This adds:
--   * capsule_title   an optional teaser shown on the sealed envelope
--   * sealed_notes()  who sealed what, and when it opens - never the text
--   * cancel_capsule() the author can withdraw a capsule while it is sealed
--   * activity feed   says "sealed a time capsule" for capsules
--   * realtime        new notes appear without refreshing
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run ONCE.
-- =============================================================================

alter table public.notes
  add column capsule_title text
    check (capsule_title is null or char_length(capsule_title) between 1 and 60);

-- Sealed capsules for your couple: envelope details only, never the body.
create or replace function public.sealed_notes()
returns table (id uuid, author_id uuid, sent_at timestamptz,
               unlock_at timestamptz, capsule_title text)
language sql stable security definer set search_path = public as $$
  select n.id, n.author_id, n.sent_at, n.unlock_at, n.capsule_title
    from notes n
   where n.couple_id = my_couple_id()
     and n.unlock_at is not null
     and n.unlock_at > now()
   order by n.unlock_at
$$;

-- The author may withdraw their own capsule before it opens.
create or replace function public.cancel_capsule(note_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from notes
   where id = note_id
     and author_id = auth.uid()
     and couple_id = my_couple_id()
     and unlock_at is not null
     and unlock_at > now();
  if not found then
    raise exception 'Only the person who sealed a capsule can cancel it, and only before it opens.';
  end if;
end;
$$;

revoke execute on function public.sealed_notes() from public, anon;
revoke execute on function public.cancel_capsule(uuid) from public, anon;
grant execute on function public.sealed_notes() to authenticated;
grant execute on function public.cancel_capsule(uuid) to authenticated;

-- Activity: mark capsules so the feed can say "sealed a time capsule".
create or replace function public.log_activity()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  row_data jsonb := to_jsonb(new);
  what     text;
  info     text;
begin
  if auth.uid() is null then
    return new;
  end if;

  case tg_table_name
    when 'memories' then
      what := 'memory_added';   info := left(row_data ->> 'caption', 120);
    when 'question_answers' then
      what := 'question_answered';
    when 'moods' then
      if not (row_data ->> 'is_shared')::boolean then
        return new;
      end if;
      what := 'mood_updated';   info := row_data ->> 'mood';
    when 'notes' then
      what := 'note_sent';      -- never the note's text
      if row_data ->> 'unlock_at' is not null then
        info := 'capsule';
      end if;
    when 'affections' then
      what := 'affection_sent'; info := row_data ->> 'kind';
    when 'important_dates' then
      what := 'date_added';     info := left(row_data ->> 'title', 120);
    when 'bucket_items' then
      what := 'bucket_added';   info := left(row_data ->> 'title', 120);
    else
      return new;
  end case;

  insert into activities (couple_id, actor_id, kind, detail)
  values ((row_data ->> 'couple_id')::uuid, auth.uid(), what, info);
  return new;
end;
$$;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime'
                       and schemaname = 'public' and tablename = 'notes') then
    alter publication supabase_realtime add table public.notes;
  end if;
end;
$$;
