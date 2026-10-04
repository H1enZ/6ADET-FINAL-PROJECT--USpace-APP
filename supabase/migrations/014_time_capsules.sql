-- =============================================================================
-- 014: Time Capsules, redesigned
--
-- A capsule is split in two so the database, not the app, keeps it sealed:
--   * time_capsules           the envelope: who, to whom, when, what state
--   * time_capsule_contents   the secret: title, letter, photo, caption
--   * time_capsule_replies    one reply each, only after it is opened
--   * capsule-photos bucket   private; access follows the contents
--
-- States and who can read what (row-level security; all writes go through
-- the functions below, never straight into the tables):
--
--                               envelope            contents / photo
--   draft                       sender              sender
--   sealed, first 10 minutes    sender              sender (edit or cancel)
--   editing (from those 10 min) sender              sender
--   sealed, after that          sender + receiver   NOBODY
--   opened                      sender + receiver   sender + receiver
--
-- "draft" is your one unsealed capsule. "editing" is a capsule you sealed
-- and reopened within its ten minutes: it does not use your draft slot,
-- has no timer, and sealing it again starts a fresh ten minutes.
--
-- Only the receiver can open it (open_time_capsule), only once unlock_at
-- has passed. Every check also names the sender or receiver, not just the
-- couple, so someone paired later into the same couple sees nothing.
--
-- Photos: no direct read access before opening (see section 5), so no
-- signed link can be made for a sealed capsule's photo.
--
-- Additive: notes, sealed_notes() and cancel_capsule() are untouched, so
-- the current app keeps working and older Love Notes capsules still open
-- the old way.
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run ONCE.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Activity kinds for capsule events. The detail is the capsule id only,
--    never its text.
-- ---------------------------------------------------------------------------

alter table public.activities drop constraint activities_kind_check;
alter table public.activities add constraint activities_kind_check
  check (kind in ('memory_added', 'question_answered', 'mood_updated',
                  'note_sent', 'affection_sent', 'date_added', 'bucket_added',
                  'capsule_opened', 'capsule_replied', 'capsule_responded'));

-- ---------------------------------------------------------------------------
-- 2. Tables
-- ---------------------------------------------------------------------------

create table public.time_capsules (
  id             uuid primary key default gen_random_uuid(),
  couple_id      uuid not null references public.couples (id) on delete cascade,
  sender_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  receiver_id    uuid references auth.users (id) on delete cascade,
  status         text not null default 'draft'
                 check (status in ('draft', 'editing', 'sealed', 'opened')),
  unlock_at      timestamptz,
  sealed_at      timestamptz,
  editable_until timestamptz,
  opened_at      timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint time_capsules_not_to_self check (receiver_id is null or receiver_id <> sender_id),
  constraint time_capsules_state check (
       (status in ('draft', 'editing')
        and sealed_at is null and editable_until is null and opened_at is null)
    or (status = 'sealed'
        and receiver_id is not null and unlock_at is not null and sealed_at is not null
        and editable_until = sealed_at + interval '10 minutes'
        and unlock_at > sealed_at and opened_at is null)
    or (status = 'opened'
        and receiver_id is not null and unlock_at is not null and sealed_at is not null
        and editable_until = sealed_at + interval '10 minutes'
        and opened_at >= unlock_at and opened_at >= editable_until)
  )
);
-- One unsealed draft per person (a capsule being edited does not count).
create unique index time_capsules_one_draft on public.time_capsules (sender_id)
  where status = 'draft';
create index time_capsules_couple_idx on public.time_capsules (couple_id, status, unlock_at);

create table public.time_capsule_contents (
  capsule_id    uuid primary key references public.time_capsules (id) on delete cascade,
  title         text check (title is null or char_length(title) between 1 and 80),
  letter        text not null default '' check (char_length(letter) <= 10000),
  photo_path    text,
  photo_caption text check (photo_caption is null or char_length(photo_caption) between 1 and 150),
  updated_at    timestamptz not null default now(),
  constraint time_capsule_caption_needs_photo check (photo_caption is null or photo_path is not null)
);

create table public.time_capsule_replies (
  capsule_id uuid not null references public.time_capsules (id) on delete cascade,
  author_id  uuid not null references auth.users (id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (capsule_id, author_id)  -- one reply each
);

-- ---------------------------------------------------------------------------
-- 3. Row-level security. Reading only; no direct writes at all.
-- ---------------------------------------------------------------------------

alter table public.time_capsules         enable row level security;
alter table public.time_capsule_contents enable row level security;
alter table public.time_capsule_replies  enable row level security;

revoke all on public.time_capsules, public.time_capsule_contents,
              public.time_capsule_replies from anon;
revoke insert, update, delete, truncate on public.time_capsules,
       public.time_capsule_contents, public.time_capsule_replies from authenticated;
grant select on public.time_capsules, public.time_capsule_contents,
                public.time_capsule_replies to authenticated;

create policy "capsules: sender, or receiver once the grace period ends"
  on public.time_capsules for select to authenticated
  using (
    couple_id = public.my_couple_id()
    and (sender_id = auth.uid()
         or (receiver_id = auth.uid()
             and status in ('sealed', 'opened')
             and editable_until <= now()))
  );

create policy "capsule contents: sender while editable, both once opened"
  on public.time_capsule_contents for select to authenticated
  using (
    exists (
      select 1 from public.time_capsules t
       where t.id = capsule_id
         and t.couple_id = public.my_couple_id()
         and ((t.sender_id = auth.uid()
               and (t.status in ('draft', 'editing')
                    or (t.status = 'sealed' and now() < t.editable_until)))
              or (t.status = 'opened' and auth.uid() in (t.sender_id, t.receiver_id)))
    )
  );

create policy "capsule replies: both, once opened"
  on public.time_capsule_replies for select to authenticated
  using (
    exists (
      select 1 from public.time_capsules t
       where t.id = capsule_id
         and t.couple_id = public.my_couple_id()
         and t.status = 'opened'
         and auth.uid() in (t.sender_id, t.receiver_id)
    )
  );

-- ---------------------------------------------------------------------------
-- 4. Functions: every change goes through one of these.
-- ---------------------------------------------------------------------------

-- The database clock, so countdowns don't depend on the device's clock.
create or replace function public.capsule_server_time()
returns timestamptz language sql stable as $$ select now() $$;

-- Internal: writes the contents of one of your unsealed capsules.
create or replace function public.capsule_write_contents(
  p_id uuid, p_title text, p_letter text, p_unlock_at timestamptz,
  p_photo_path text, p_photo_caption text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_couple uuid := my_couple_id();
  v_title  text := nullif(btrim(coalesce(p_title, '')), '');
  v_cap    text := nullif(btrim(coalesce(p_photo_caption, '')), '');
begin
  if p_photo_path is not null
     and p_photo_path not like v_couple::text || '/' || p_id::text || '/%' then
    raise exception 'That photo does not belong to this capsule.';
  end if;
  insert into time_capsule_contents
         (capsule_id, title, letter, photo_path, photo_caption, updated_at)
  values (p_id, v_title, coalesce(p_letter, ''), p_photo_path, v_cap, now())
  on conflict (capsule_id) do update
     set title = excluded.title, letter = excluded.letter,
         photo_path = excluded.photo_path, photo_caption = excluded.photo_caption,
         updated_at = now();
  update time_capsules set unlock_at = p_unlock_at, updated_at = now()
   where id = p_id;
end;
$$;

-- Saves (or starts) your one draft. Returns its id.
create or replace function public.save_capsule_draft(
  p_title text, p_letter text, p_unlock_at timestamptz,
  p_photo_path text, p_photo_caption text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  me     uuid := auth.uid();
  couple uuid := my_couple_id();
  v_id   uuid;
begin
  if me is null or couple is null then
    raise exception 'Link with your partner before writing a time capsule.';
  end if;
  select id into v_id from time_capsules
   where sender_id = me and status = 'draft' for update;
  if v_id is null then
    insert into time_capsules (couple_id, sender_id) values (couple, me)
      returning id into v_id;
  end if;
  perform capsule_write_contents(v_id, p_title, p_letter, p_unlock_at,
                                 p_photo_path, p_photo_caption);
  return v_id;
end;
$$;

-- Saves changes to a capsule you reopened during its ten minutes.
create or replace function public.save_capsule_edit(
  p_id uuid, p_title text, p_letter text, p_unlock_at timestamptz,
  p_photo_path text, p_photo_caption text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform 1 from time_capsules
   where id = p_id and sender_id = auth.uid() and couple_id = my_couple_id()
     and status = 'editing'
   for update;
  if not found then
    raise exception 'This capsule is no longer being edited.';
  end if;
  perform capsule_write_contents(p_id, p_title, p_letter, p_unlock_at,
                                 p_photo_path, p_photo_caption);
end;
$$;

-- Deletes your draft. Remove its photo from storage first (the app does).
create or replace function public.delete_capsule_draft(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from time_capsules
   where id = p_id and sender_id = auth.uid() and status = 'draft';
  if not found then
    raise exception 'That draft is no longer there.';
  end if;
end;
$$;

-- Seals your draft (or a capsule you were editing). Your partner sees
-- nothing for the next ten minutes, while you can still edit or cancel it.
-- Returns when those ten minutes end.
create or replace function public.seal_time_capsule(p_id uuid)
returns timestamptz language plpgsql security definer set search_path = public as $$
declare
  me       uuid := auth.uid();
  couple   uuid := my_couple_id();
  partner  uuid;
  c        time_capsules;
  v_body   time_capsule_contents;
begin
  select * into c from time_capsules
   where id = p_id and sender_id = me and couple_id = couple
     and status in ('draft', 'editing')
   for update;
  if not found then
    raise exception 'That capsule is no longer there.';
  end if;
  select * into v_body from time_capsule_contents where capsule_id = p_id;
  if v_body.capsule_id is null or btrim(v_body.letter) = '' then
    raise exception 'Write your letter before sealing.';
  end if;
  if c.unlock_at is null or c.unlock_at <= now() then
    raise exception 'Choose a moment in the future for it to open.';
  end if;
  if v_body.photo_path is not null and not exists (
       select 1 from storage.objects o
        where o.bucket_id = 'capsule-photos' and o.name = v_body.photo_path) then
    raise exception 'The photo did not finish uploading. Add it again, or remove it.';
  end if;
  select user_id into partner from profiles
   where couple_id = couple and user_id <> me;
  if partner is null then
    raise exception 'Link with your partner before sealing a time capsule.';
  end if;

  update time_capsules
     set status = 'sealed', receiver_id = partner, sealed_at = now(),
         editable_until = now() + interval '10 minutes', updated_at = now()
   where id = p_id;
  return now() + interval '10 minutes';
end;
$$;

-- During the ten minutes: reopen it to change anything. It stays hidden
-- from your partner, has no timer while you edit, and does not use your
-- draft slot. Sealing it again starts a fresh ten minutes.
create or replace function public.edit_time_capsule(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update time_capsules
     set status = 'editing', receiver_id = null, sealed_at = null,
         editable_until = null, updated_at = now()
   where id = p_id and sender_id = auth.uid() and couple_id = my_couple_id()
     and status = 'sealed' and now() < editable_until;
  if not found then
    raise exception 'This capsule is sealed for good now.';
  end if;
end;
$$;

-- During the ten minutes, or while editing: withdraw it. Your partner
-- never knew. Remove its photo from storage first (the app does).
create or replace function public.cancel_time_capsule(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from time_capsules
   where id = p_id and sender_id = auth.uid() and couple_id = my_couple_id()
     and (status = 'editing' or (status = 'sealed' and now() < editable_until));
  if not found then
    raise exception 'This capsule is sealed for good now.';
  end if;
end;
$$;

-- The receiver opens it, at or after its moment. Safe to call twice: the
-- second call just returns the contents again.
create or replace function public.open_time_capsule(p_id uuid)
returns setof public.time_capsule_contents
language plpgsql security definer set search_path = public as $$
declare
  me     uuid := auth.uid();
  couple uuid := my_couple_id();
  c      time_capsules;
begin
  select * into c from time_capsules
   where id = p_id and couple_id = couple and receiver_id = me
   for update;
  if not found or c.status not in ('sealed', 'opened') then
    raise exception 'Only the person it was written for can open it.';
  end if;
  if c.status = 'sealed' then
    if now() < c.unlock_at or now() < c.editable_until then
      raise exception 'It is not time to open this yet.';
    end if;
    update time_capsules set status = 'opened', opened_at = now(), updated_at = now()
     where id = p_id;
    insert into activities (couple_id, actor_id, kind, detail)
    values (couple, me, 'capsule_opened', p_id::text);
  end if;
  return query select * from time_capsule_contents where capsule_id = p_id;
end;
$$;

-- One reply each, after opening. The receiver goes first; the sender then
-- answers once. The receiver can change their words until the sender
-- answers; after that both replies are permanent.
create or replace function public.reply_time_capsule(p_id uuid, p_body text)
returns void language plpgsql security definer set search_path = public as $$
declare
  me       uuid := auth.uid();
  c        time_capsules;
  v_body   text := btrim(coalesce(p_body, ''));
  is_first boolean;
  replies  int;
begin
  select * into c from time_capsules
   where id = p_id and couple_id = my_couple_id() and status = 'opened'
     and me in (sender_id, receiver_id)
   for update;
  if not found then
    raise exception 'You can reply once the capsule is opened.';
  end if;
  if char_length(v_body) not between 1 and 500 then
    raise exception 'Keep your reply between 1 and 500 characters.';
  end if;
  select count(*) into replies from time_capsule_replies r where r.capsule_id = p_id;
  if replies = 2 then
    raise exception 'You have both replied; your words are kept as they are.';
  end if;
  if me = c.sender_id and not exists (
       select 1 from time_capsule_replies r
        where r.capsule_id = p_id and r.author_id = c.receiver_id) then
    raise exception 'Your partner replies first.';
  end if;

  is_first := not exists (select 1 from time_capsule_replies r
                           where r.capsule_id = p_id and r.author_id = me);
  insert into time_capsule_replies (capsule_id, author_id, body)
  values (p_id, me, v_body)
  on conflict (capsule_id, author_id) do update
     set body = excluded.body, updated_at = now();

  if is_first then
    insert into activities (couple_id, actor_id, kind, detail)
    values (c.couple_id, me,
            case when me = c.receiver_id then 'capsule_replied' else 'capsule_responded' end,
            p_id::text);
  end if;
end;
$$;

revoke execute on function public.capsule_write_contents(uuid, text, text, timestamptz, text, text) from public, anon, authenticated;
revoke execute on function public.capsule_server_time() from public, anon;
revoke execute on function public.save_capsule_draft(text, text, timestamptz, text, text) from public, anon;
revoke execute on function public.save_capsule_edit(uuid, text, text, timestamptz, text, text) from public, anon;
revoke execute on function public.delete_capsule_draft(uuid) from public, anon;
revoke execute on function public.seal_time_capsule(uuid) from public, anon;
revoke execute on function public.edit_time_capsule(uuid) from public, anon;
revoke execute on function public.cancel_time_capsule(uuid) from public, anon;
revoke execute on function public.open_time_capsule(uuid) from public, anon;
revoke execute on function public.reply_time_capsule(uuid, text) from public, anon;
grant execute on function public.capsule_server_time() to authenticated;
grant execute on function public.save_capsule_draft(text, text, timestamptz, text, text) to authenticated;
grant execute on function public.save_capsule_edit(uuid, text, text, timestamptz, text, text) to authenticated;
grant execute on function public.delete_capsule_draft(uuid) to authenticated;
grant execute on function public.seal_time_capsule(uuid) to authenticated;
grant execute on function public.edit_time_capsule(uuid) to authenticated;
grant execute on function public.cancel_time_capsule(uuid) to authenticated;
grant execute on function public.open_time_capsule(uuid) to authenticated;
grant execute on function public.reply_time_capsule(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Private photo storage: capsule-photos/<couple>/<capsule>/<file>.
--
--    Nobody's own session can read a capsule photo until the receiver has
--    opened the capsule. That also means nobody can make a signed link to
--    it before then (signing needs read access), so no link made earlier
--    can outlive the moment it is sealed for good.
--
--      draft / editing           the sender uploads with their session;
--                                previews and removals go through the
--                                capsule-photo Edge Function, which checks
--                                capsule_photo_access() and serves the
--                                bytes itself (never a link)
--      grace (sealed)            nobody: to change or cancel it, the sender
--                                first reopens it (edit_time_capsule)
--      sealed / ready            nobody, by any route
--      opened                    sender and receiver read it directly;
--                                nobody can replace or delete it
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('capsule-photos', 'capsule-photos', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "capsule photos: read once opened" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'capsule-photos'
    and exists (
      select 1
        from public.time_capsule_contents c
        join public.time_capsules t on t.id = c.capsule_id
       where c.photo_path = objects.name
         and t.status = 'opened'
         and t.couple_id = public.my_couple_id()
         and auth.uid() in (t.sender_id, t.receiver_id))
  );

create policy "capsule photos: add while unsealed" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'capsule-photos'
    and (storage.foldername(name))[1] = public.my_couple_id()::text
    and exists (
      select 1 from public.time_capsules t
       where t.id::text = (storage.foldername(name))[2]
         and t.couple_id = public.my_couple_id()
         and t.sender_id = auth.uid()
         and t.status in ('draft', 'editing'))
  );

-- For the capsule-photo Edge Function only (service role): may this person
-- preview or tidy this capsule's photos right now? Returns the capsule's
-- folder and current photo when they are its sender and it is a draft or
-- being edited; otherwise nothing (a sealed capsule, even within its ten
-- minutes, must be reopened first). The person is the Edge Function's
-- verified caller, never a value from the app.
create or replace function public.capsule_photo_access(p_capsule uuid, p_user uuid)
returns table (folder text, photo_path text)
language sql stable security definer set search_path = public as $$
  select t.couple_id::text || '/' || t.id::text, c.photo_path
    from time_capsules t
    join profiles p on p.user_id = p_user and p.couple_id = t.couple_id
    left join time_capsule_contents c on c.capsule_id = t.id
   where t.id = p_capsule
     and t.sender_id = p_user
     and t.status in ('draft', 'editing')
$$;

revoke execute on function public.capsule_photo_access(uuid, uuid) from public, anon, authenticated;
grant execute on function public.capsule_photo_access(uuid, uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 6. Realtime: envelopes only (row-level security still decides who
--    receives what). Never the contents; replies are announced through the
--    activity feed. Subscribe with a couple_id filter: an unfiltered
--    subscription would receive the id of a capsule cancelled during its
--    grace period.
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables
                    where pubname = 'supabase_realtime'
                      and schemaname = 'public' and tablename = 'time_capsules') then
      alter publication supabase_realtime add table public.time_capsules;
    end if;
  end if;
end;
$$;
