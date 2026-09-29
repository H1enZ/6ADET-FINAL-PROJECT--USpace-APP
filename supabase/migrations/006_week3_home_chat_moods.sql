-- =============================================================================
-- 006: Week 3 - richer memories, private chat, moods, daily questions,
--      important dates, affection, resolution notes and an activity feed.
--
-- The same rule as every other table: a row is only visible to the two
-- people in its couple. Some rows are more private still (explained below).
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run ONCE.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Keeps updated_at current on every edit.
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Messages get the server's time, so nobody can back-date a message.
create or replace function public.set_created_now()
returns trigger language plpgsql as $$
begin
  new.created_at := now();
  return new;
end;
$$;


-- ---------------------------------------------------------------------------
-- 1. Richer memories: description, location, tags, edit time, many photos.
--    `caption` stays and is shown as the memory's title.
-- ---------------------------------------------------------------------------

alter table public.memories
  add column description text
    check (description is null or char_length(description) <= 4000),
  add column location text
    check (location is null or char_length(location) between 1 and 120),
  add column tags text[] not null default '{}'
    check (tags <@ array['first_date', 'anniversary', 'travel', 'celebration',
                         'everyday', 'special']::text[]
           and cardinality(tags) <= 6),
  add column updated_at timestamptz not null default now();

create trigger memories_updated_at
  before update on public.memories
  for each row execute function public.set_updated_at();

-- Up to 10 photos per memory, stored in the private memory-photos bucket
-- under the couple's folder. memories.photo_path stays as the cover photo.
create table public.memory_photos (
  id         uuid primary key default gen_random_uuid(),
  memory_id  uuid not null references public.memories (id) on delete cascade,
  couple_id  uuid not null references public.couples (id) on delete cascade,
  path       text not null check (char_length(path) between 1 and 300),
  position   smallint not null default 0 check (position between 0 and 9),
  created_at timestamptz not null default now(),
  unique (memory_id, position)
);
create index memory_photos_memory_idx on public.memory_photos (memory_id);

alter table public.memory_photos enable row level security;
revoke update on public.memory_photos from anon, authenticated;

create policy "memory photos: couple read" on public.memory_photos
  for select to authenticated using (couple_id = public.my_couple_id());

-- Only the memory's author adds or removes its photos, and only files in
-- their own couple's folder.
create policy "memory photos: author insert" on public.memory_photos
  for insert to authenticated
  with check (
    couple_id = public.my_couple_id()
    and split_part(path, '/', 1) = public.my_couple_id()::text
    and exists (select 1 from public.memories m
                where m.id = memory_id and m.author_id = auth.uid()
                  and m.couple_id = public.my_couple_id())
  );

create policy "memory photos: author delete" on public.memory_photos
  for delete to authenticated
  using (
    couple_id = public.my_couple_id()
    and exists (select 1 from public.memories m
                where m.id = memory_id and m.author_id = auth.uid())
  );


-- ---------------------------------------------------------------------------
-- 2. Private chat
-- ---------------------------------------------------------------------------

create table public.messages (
  id         uuid primary key default gen_random_uuid(),
  couple_id  uuid not null references public.couples (id) on delete cascade,
  sender_id  uuid not null default auth.uid() references auth.users (id) on delete cascade,
  body       text check (body is null or char_length(body) between 1 and 4000),
  photo_path text check (photo_path is null or char_length(photo_path) <= 300),
  created_at timestamptz not null default now(),
  edited_at  timestamptz,
  deleted_at timestamptz,
  read_at    timestamptz,
  -- a message has text or a photo, unless it was deleted
  check (deleted_at is not null or body is not null or photo_path is not null)
);
create index messages_couple_time_idx on public.messages (couple_id, created_at desc);

create trigger messages_created_now
  before insert on public.messages
  for each row execute function public.set_created_now();

alter table public.messages enable row level security;
-- Edits, deletes and read receipts only happen through the functions below.
revoke update, delete on public.messages from anon, authenticated;

create policy "messages: couple read" on public.messages
  for select to authenticated using (couple_id = public.my_couple_id());

-- You can only send as yourself, into your own couple, and a new message
-- cannot arrive already "read", "edited" or "deleted".
create policy "messages: send as myself" on public.messages
  for insert to authenticated
  with check (
    couple_id = public.my_couple_id()
    and sender_id = auth.uid()
    and edited_at is null and deleted_at is null and read_at is null
    and (photo_path is null
         or split_part(photo_path, '/', 1) = public.my_couple_id()::text)
  );

create or replace function public.edit_message(message_id uuid, new_body text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if new_body is null or char_length(trim(new_body)) = 0
     or char_length(new_body) > 4000 then
    raise exception 'A message must be 1 to 4000 characters.';
  end if;
  update messages
     set body = trim(new_body), edited_at = now()
   where id = message_id and sender_id = auth.uid()
     and couple_id = my_couple_id() and deleted_at is null;
  if not found then
    raise exception 'You can only edit your own messages.';
  end if;
end;
$$;

-- Clears the text and photo; returns the photo path so the app can delete
-- the file from Storage too.
create or replace function public.delete_message(message_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  old_photo text;
begin
  select photo_path into old_photo from messages
   where id = message_id and sender_id = auth.uid()
     and couple_id = my_couple_id() and deleted_at is null;
  if not found then
    raise exception 'You can only delete your own messages.';
  end if;
  update messages
     set body = null, photo_path = null, deleted_at = now()
   where id = message_id;
  return old_photo;
end;
$$;

-- Marks your partner's messages to you as read. Returns how many.
create or replace function public.mark_messages_read()
returns integer language plpgsql security definer set search_path = public as $$
declare
  changed integer;
begin
  update messages set read_at = now()
   where couple_id = my_couple_id() and sender_id <> auth.uid()
     and read_at is null;
  get diagnostics changed = row_count;
  return changed;
end;
$$;

create table public.message_reactions (
  message_id uuid not null references public.messages (id) on delete cascade,
  couple_id  uuid not null references public.couples (id) on delete cascade,
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  emoji      text not null check (emoji in ('❤️', '😂', '😮', '😢', '🥰', '👍')),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)       -- one reaction each per message
);

alter table public.message_reactions enable row level security;

create policy "reactions: couple read" on public.message_reactions
  for select to authenticated using (couple_id = public.my_couple_id());
create policy "reactions: react as myself" on public.message_reactions
  for insert to authenticated
  with check (
    user_id = auth.uid() and couple_id = public.my_couple_id()
    and exists (select 1 from public.messages m
                where m.id = message_id and m.couple_id = public.my_couple_id())
  );
create policy "reactions: change my own" on public.message_reactions
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and couple_id = public.my_couple_id());
create policy "reactions: remove my own" on public.message_reactions
  for delete to authenticated using (user_id = auth.uid());


-- ---------------------------------------------------------------------------
-- 3. Daily mood. Each check-in is a new row (you can check in again later
--    in the day). A check-in marked not shared is visible only to its owner.
-- ---------------------------------------------------------------------------

create table public.moods (
  id         uuid primary key default gen_random_uuid(),
  couple_id  uuid not null references public.couples (id) on delete cascade,
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  mood       text not null check (mood in ('happy', 'loved', 'excited', 'relaxed',
                'tired', 'stressed', 'sad', 'anxious', 'lonely', 'upset')),
  note       text check (note is null or char_length(note) <= 280),
  is_shared  boolean not null default true,
  created_at timestamptz not null default now()
);
create index moods_couple_time_idx on public.moods (couple_id, created_at desc);

alter table public.moods enable row level security;
revoke update on public.moods from anon, authenticated;

create policy "moods: mine, or my partner's shared ones" on public.moods
  for select to authenticated
  using (user_id = auth.uid()
         or (couple_id = public.my_couple_id() and is_shared));
create policy "moods: check in as myself" on public.moods
  for insert to authenticated
  with check (user_id = auth.uid() and couple_id = public.my_couple_id());
create policy "moods: delete my own" on public.moods
  for delete to authenticated using (user_id = auth.uid());


-- ---------------------------------------------------------------------------
-- 4. Daily question answers. The question text is stored with the answer so
--    the archive still makes sense if the app's question list changes.
--    Your partner's answer only becomes visible after you answer the same
--    day's question yourself.
-- ---------------------------------------------------------------------------

create table public.question_answers (
  id            uuid primary key default gen_random_uuid(),
  couple_id     uuid not null references public.couples (id) on delete cascade,
  user_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  question_date date not null check (question_date <= current_date + 1),
  question      text not null check (char_length(question) between 1 and 300),
  answer        text not null check (char_length(answer) between 1 and 2000),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (user_id, question_date)
);
create index question_answers_couple_date_idx
  on public.question_answers (couple_id, question_date desc);

create trigger question_answers_updated_at
  before update on public.question_answers
  for each row execute function public.set_updated_at();

-- security definer so the policy below can check "did I answer?" without
-- the policy calling itself.
create or replace function public.i_answered(d date)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from question_answers
                 where user_id = auth.uid() and question_date = d)
$$;

alter table public.question_answers enable row level security;

create policy "answers: mine, or my partner's once I answered" on public.question_answers
  for select to authenticated
  using (user_id = auth.uid()
         or (couple_id = public.my_couple_id() and public.i_answered(question_date)));
create policy "answers: answer as myself" on public.question_answers
  for insert to authenticated
  with check (user_id = auth.uid() and couple_id = public.my_couple_id());
create policy "answers: edit my own" on public.question_answers
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and couple_id = public.my_couple_id());


-- ---------------------------------------------------------------------------
-- 5. Important dates (shared; either partner can add, edit or remove).
-- ---------------------------------------------------------------------------

create table public.important_dates (
  id             uuid primary key default gen_random_uuid(),
  couple_id      uuid not null references public.couples (id) on delete cascade,
  created_by     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title          text not null check (char_length(title) between 1 and 80),
  event_date     date not null,
  repeats_yearly boolean not null default true,
  created_at     timestamptz not null default now()
);

alter table public.important_dates enable row level security;

create policy "dates: couple all" on public.important_dates
  for all to authenticated
  using (couple_id = public.my_couple_id())
  with check (couple_id = public.my_couple_id());


-- ---------------------------------------------------------------------------
-- 6. Affection and support sent to your partner (hugs, kisses, comfort,
--    "please just listen"). Only the receiver can mark them as seen.
-- ---------------------------------------------------------------------------

create table public.affections (
  id         uuid primary key default gen_random_uuid(),
  couple_id  uuid not null references public.couples (id) on delete cascade,
  sender_id  uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind       text not null check (kind in ('hug', 'kiss', 'cuddle', 'comfort', 'listen')),
  message    text check (message is null or char_length(message) <= 1000),
  created_at timestamptz not null default now(),
  seen_at    timestamptz
);
create index affections_couple_time_idx on public.affections (couple_id, created_at desc);

alter table public.affections enable row level security;
revoke update on public.affections from anon, authenticated;

create policy "affections: couple read" on public.affections
  for select to authenticated using (couple_id = public.my_couple_id());
create policy "affections: send as myself" on public.affections
  for insert to authenticated
  with check (sender_id = auth.uid() and couple_id = public.my_couple_id()
              and seen_at is null);
create policy "affections: unsend my own" on public.affections
  for delete to authenticated using (sender_id = auth.uid());

create or replace function public.mark_affections_seen()
returns integer language plpgsql security definer set search_path = public as $$
declare
  changed integer;
begin
  update affections set seen_at = now()
   where couple_id = my_couple_id() and sender_id <> auth.uid()
     and seen_at is null;
  get diagnostics changed = row_count;
  return changed;
end;
$$;


-- ---------------------------------------------------------------------------
-- 7. "Let's work it out" resolution notes. Each person writes their own.
--    A note kept private (is_shared = false) is visible only to its author.
-- ---------------------------------------------------------------------------

create table public.resolution_notes (
  id                 uuid primary key default gen_random_uuid(),
  couple_id          uuid not null references public.couples (id) on delete cascade,
  author_id          uuid not null default auth.uid() references auth.users (id) on delete cascade,
  need               text not null check (need in ('solution', 'comfort', 'affection', 'listen')),
  what_happened      text check (what_happened      is null or char_length(what_happened)      <= 2000),
  how_it_felt        text check (how_it_felt        is null or char_length(how_it_felt)        <= 2000),
  what_we_need       text check (what_we_need       is null or char_length(what_we_need)       <= 2000),
  next_time          text check (next_time          is null or char_length(next_time)          <= 2000),
  apology_or_clarify text check (apology_or_clarify is null or char_length(apology_or_clarify) <= 2000),
  reconnect          text check (reconnect          is null or char_length(reconnect)          <= 2000),
  status             text not null default 'paused' check (status in ('paused', 'done')),
  is_shared          boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create trigger resolution_notes_updated_at
  before update on public.resolution_notes
  for each row execute function public.set_updated_at();

alter table public.resolution_notes enable row level security;

create policy "resolution: mine, or my partner's shared ones" on public.resolution_notes
  for select to authenticated
  using (author_id = auth.uid()
         or (couple_id = public.my_couple_id() and is_shared));
create policy "resolution: write as myself" on public.resolution_notes
  for insert to authenticated
  with check (author_id = auth.uid() and couple_id = public.my_couple_id());
create policy "resolution: edit my own" on public.resolution_notes
  for update to authenticated
  using (author_id = auth.uid())
  with check (author_id = auth.uid() and couple_id = public.my_couple_id());
create policy "resolution: delete my own" on public.resolution_notes
  for delete to authenticated using (author_id = auth.uid());


-- ---------------------------------------------------------------------------
-- 8. Activity feed, written only by the database (triggers below), so the
--    app cannot fake entries. Never stores mood notes or message text.
-- ---------------------------------------------------------------------------

create table public.activities (
  id         uuid primary key default gen_random_uuid(),
  couple_id  uuid not null references public.couples (id) on delete cascade,
  actor_id   uuid not null references auth.users (id) on delete cascade,
  kind       text not null check (kind in ('memory_added', 'question_answered',
                'mood_updated', 'note_sent', 'affection_sent', 'date_added',
                'bucket_added')),
  detail     text check (detail is null or char_length(detail) <= 120),
  created_at timestamptz not null default now()
);
create index activities_couple_time_idx on public.activities (couple_id, created_at desc);

alter table public.activities enable row level security;
revoke insert, update, delete on public.activities from anon, authenticated;

create policy "activities: couple read" on public.activities
  for select to authenticated using (couple_id = public.my_couple_id());

create or replace function public.log_activity()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  row_data jsonb := to_jsonb(new);
  what     text;
  info     text;
begin
  if auth.uid() is null then
    return new;                       -- changes made by an admin are not logged
  end if;

  case tg_table_name
    when 'memories' then
      what := 'memory_added';   info := left(row_data ->> 'caption', 120);
    when 'question_answers' then
      what := 'question_answered';
    when 'moods' then
      if not (row_data ->> 'is_shared')::boolean then
        return new;                   -- private check-ins stay private
      end if;
      what := 'mood_updated';   info := row_data ->> 'mood';
    when 'notes' then
      what := 'note_sent';            -- never the note's text
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

create trigger memories_activity after insert on public.memories
  for each row execute function public.log_activity();
create trigger question_answers_activity after insert on public.question_answers
  for each row execute function public.log_activity();
create trigger moods_activity after insert on public.moods
  for each row execute function public.log_activity();
create trigger notes_activity after insert on public.notes
  for each row execute function public.log_activity();
create trigger affections_activity after insert on public.affections
  for each row execute function public.log_activity();
create trigger important_dates_activity after insert on public.important_dates
  for each row execute function public.log_activity();
create trigger bucket_items_activity after insert on public.bucket_items
  for each row execute function public.log_activity();


-- ---------------------------------------------------------------------------
-- 9. Function permissions: signed-in users only.
-- ---------------------------------------------------------------------------

revoke execute on function public.edit_message(uuid, text) from public, anon;
revoke execute on function public.delete_message(uuid) from public, anon;
revoke execute on function public.mark_messages_read() from public, anon;
revoke execute on function public.mark_affections_seen() from public, anon;
revoke execute on function public.i_answered(date) from public, anon;
grant execute on function public.edit_message(uuid, text) to authenticated;
grant execute on function public.delete_message(uuid) to authenticated;
grant execute on function public.mark_messages_read() to authenticated;
grant execute on function public.mark_affections_seen() to authenticated;
grant execute on function public.i_answered(date) to authenticated;


-- ---------------------------------------------------------------------------
-- 10. Realtime: new messages, reactions, affection and activity appear
--     without refreshing. Realtime still applies the row-level security above.
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['messages', 'message_reactions', 'affections', 'activities']
    loop
      if not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime'
                       and schemaname = 'public' and tablename = t) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end;
$$;
