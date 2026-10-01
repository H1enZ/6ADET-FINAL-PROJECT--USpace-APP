-- =============================================================================
-- USpace database: tables, row-level security, pairing functions, photo bucket
--
-- HOW TO USE: Supabase dashboard > SQL Editor > New query > paste this whole
-- file > Run. Run it ONCE on a fresh project.
--
-- THE ONE RULE behind every policy below:
--   a row is visible only if its couple_id matches the signed-in user's couple.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------

create table public.couples (
  id               uuid primary key default gen_random_uuid(),
  pairing_code     text not null unique,
  anniversary_date date,
  created_at       timestamptz not null default now()
);

create table public.profiles (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  couple_id    uuid references public.couples (id) on delete set null,
  display_name text not null check (char_length(display_name) between 1 and 40),
  avatar_path  text,
  created_at   timestamptz not null default now()
);

-- "current_date + 1" instead of "current_date": the database runs on UTC and
-- the Philippines is UTC+8, so "today" in Manila can be "tomorrow" in UTC.
create table public.memories (
  id          uuid primary key default gen_random_uuid(),
  couple_id   uuid not null references public.couples (id) on delete cascade,
  author_id   uuid not null default auth.uid() references auth.users (id) on delete cascade,
  caption     text not null check (char_length(caption) between 1 and 500),
  memory_date date not null check (memory_date <= current_date + 1),
  photo_path  text,
  is_favorite boolean not null default false,
  created_at  timestamptz not null default now()
);

-- unlock_at is null for an ordinary note, and a future time for a Time Capsule.
create table public.notes (
  id          uuid primary key default gen_random_uuid(),
  couple_id   uuid not null references public.couples (id) on delete cascade,
  author_id   uuid not null default auth.uid() references auth.users (id) on delete cascade,
  body        text not null check (char_length(body) between 1 and 2000),
  is_favorite boolean not null default false,
  sent_at     timestamptz not null default now(),
  unlock_at   timestamptz check (unlock_at is null or unlock_at > sent_at)
);

create table public.bucket_items (
  id           uuid primary key default gen_random_uuid(),
  couple_id    uuid not null references public.couples (id) on delete cascade,
  title        text not null check (char_length(title) between 1 and 120),
  target_date  date,
  is_done      boolean not null default false,
  completed_at timestamptz,
  created_at   timestamptz not null default now()
);

create index profiles_couple_idx on public.profiles (couple_id);
create index memories_couple_date_idx on public.memories (couple_id, memory_date desc);
create index notes_couple_sent_idx on public.notes (couple_id, sent_at desc);
create index bucket_couple_idx on public.bucket_items (couple_id);


-- ---------------------------------------------------------------------------
-- 2. Helper: which couple is the signed-in user in?
--    "security definer" lets policies call it without the profiles policy
--    calling itself in a loop.
-- ---------------------------------------------------------------------------

create or replace function public.my_couple_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select couple_id from public.profiles where user_id = auth.uid()
$$;


-- ---------------------------------------------------------------------------
-- 3. A profile is created automatically for every new account.
--    The display name comes from the sign-up form (user metadata).
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id, display_name)
  values (
    new.id,
    left(coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
                  split_part(new.email, '@', 1)), 40)
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ---------------------------------------------------------------------------
-- 4. Pairing. These are the ONLY way to create or join a couple, so nobody
--    can attach themselves to another couple by editing their profile.
-- ---------------------------------------------------------------------------

create or replace function public.create_couple(anniversary date default null)
returns public.couples
language plpgsql
security definer
set search_path = public
as $$
declare
  alphabet   text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';  -- no 0/O or 1/I
  new_code   text;
  new_couple public.couples;
begin
  if auth.uid() is null then
    raise exception 'Sign in first.';
  end if;
  if exists (select 1 from profiles where user_id = auth.uid() and couple_id is not null) then
    raise exception 'You are already paired.';
  end if;
  if anniversary is not null and anniversary > current_date + 1 then
    raise exception 'Your anniversary can''t be in the future.';
  end if;

  loop
    new_code := '';
    for i in 1..6 loop
      new_code := new_code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from couples where pairing_code = new_code);
  end loop;

  insert into couples (pairing_code, anniversary_date)
  values (new_code, anniversary)
  returning * into new_couple;

  update profiles set couple_id = new_couple.id where user_id = auth.uid();
  return new_couple;
end;
$$;

create or replace function public.join_couple(code text)
returns public.couples
language plpgsql
security definer
set search_path = public
as $$
declare
  target       public.couples;
  member_count int;
begin
  if auth.uid() is null then
    raise exception 'Sign in first.';
  end if;
  if exists (select 1 from profiles where user_id = auth.uid() and couple_id is not null) then
    raise exception 'You are already paired.';
  end if;

  -- "for update" locks the couple row so two people can't join at the same instant
  select * into target from couples where pairing_code = upper(trim(code)) for update;
  if not found then
    raise exception 'No couple matches that code. Check it with your partner.';
  end if;

  select count(*) into member_count from profiles where couple_id = target.id;
  if member_count >= 2 then
    raise exception 'That couple already has two people.';
  end if;

  update profiles set couple_id = target.id where user_id = auth.uid();
  return target;
end;
$$;

revoke execute on function public.create_couple(date) from public, anon;
revoke execute on function public.join_couple(text) from public, anon;
grant execute on function public.create_couple(date) to authenticated;
grant execute on function public.join_couple(text) to authenticated;


-- ---------------------------------------------------------------------------
-- 5. Column permissions: which columns the app may change directly.
--    couple_id and pairing_code are NOT in these lists, so only the
--    functions above can set them.
-- ---------------------------------------------------------------------------

revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (display_name, avatar_path) on public.profiles to authenticated;

revoke insert, update, delete on public.couples from anon, authenticated;
grant update (anniversary_date) on public.couples to authenticated;


-- ---------------------------------------------------------------------------
-- 6. Row-level security
-- ---------------------------------------------------------------------------

alter table public.couples      enable row level security;
alter table public.profiles     enable row level security;
alter table public.memories     enable row level security;
alter table public.notes        enable row level security;
alter table public.bucket_items enable row level security;

-- Couples: you see and edit only your own.
create policy "couples: members read" on public.couples
  for select to authenticated using (id = public.my_couple_id());
create policy "couples: members update" on public.couples
  for update to authenticated
  using (id = public.my_couple_id()) with check (id = public.my_couple_id());

-- Profiles: you see yourself and your partner; you edit only yourself.
create policy "profiles: self and partner read" on public.profiles
  for select to authenticated
  using (user_id = auth.uid() or (couple_id is not null and couple_id = public.my_couple_id()));
create policy "profiles: self update" on public.profiles
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Memories: both partners read; only the author adds, edits or deletes.
create policy "memories: couple read" on public.memories
  for select to authenticated using (couple_id = public.my_couple_id());
create policy "memories: author insert" on public.memories
  for insert to authenticated
  with check (couple_id = public.my_couple_id() and author_id = auth.uid());
create policy "memories: author update" on public.memories
  for update to authenticated
  using (couple_id = public.my_couple_id() and author_id = auth.uid())
  with check (couple_id = public.my_couple_id() and author_id = auth.uid());
create policy "memories: author delete" on public.memories
  for delete to authenticated
  using (couple_id = public.my_couple_id() and author_id = auth.uid());

-- Notes: a sealed Time Capsule stays invisible to BOTH partners until
-- unlock_at, enforced here in the database, not in the app.
-- (The seal and countdown will come from a separate function that returns
-- only the unlock time, never the body. That is the Time Capsule week.)
create policy "notes: couple read when unlocked" on public.notes
  for select to authenticated
  using (couple_id = public.my_couple_id() and (unlock_at is null or unlock_at <= now()));
create policy "notes: author insert" on public.notes
  for insert to authenticated
  with check (couple_id = public.my_couple_id() and author_id = auth.uid());
create policy "notes: couple favourite" on public.notes
  for update to authenticated
  using (couple_id = public.my_couple_id() and (unlock_at is null or unlock_at <= now()))
  with check (couple_id = public.my_couple_id());
create policy "notes: author delete" on public.notes
  for delete to authenticated
  using (couple_id = public.my_couple_id() and author_id = auth.uid());

revoke update on public.notes from anon, authenticated;
grant update (is_favorite) on public.notes to authenticated;

-- Bucket list: shared, so either partner can do anything with it.
create policy "bucket: couple all" on public.bucket_items
  for all to authenticated
  using (couple_id = public.my_couple_id())
  with check (couple_id = public.my_couple_id());


-- ---------------------------------------------------------------------------
-- 7. Private photo bucket. Files are stored as  <couple_id>/<file name>,
--    and only members of that couple can read, upload or delete them.
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('memory-photos', 'memory-photos', false)
on conflict (id) do nothing;

create policy "photos: couple read" on storage.objects
  for select to authenticated
  using (bucket_id = 'memory-photos'
         and (storage.foldername(name))[1] = public.my_couple_id()::text);
create policy "photos: couple upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'memory-photos'
              and (storage.foldername(name))[1] = public.my_couple_id()::text);
create policy "photos: couple delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'memory-photos'
         and (storage.foldername(name))[1] = public.my_couple_id()::text);


-- ---------------------------------------------------------------------------
-- 8. Either partner can favourite a memory (also in migrations/002).
--    Flips only is_favorite, only inside the caller's own couple.
-- ---------------------------------------------------------------------------

create or replace function public.toggle_memory_favorite(memory_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  new_value boolean;
begin
  update memories
     set is_favorite = not is_favorite
   where id = memory_id
     and couple_id = public.my_couple_id()
  returning is_favorite into new_value;

  if new_value is null then
    raise exception 'Memory not found.';
  end if;
  return new_value;
end;
$$;

revoke execute on function public.toggle_memory_favorite(uuid) from public, anon;
grant execute on function public.toggle_memory_favorite(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 9. Bucket list details and savings log (also in migrations/003).
-- ---------------------------------------------------------------------------

alter table public.bucket_items
  add column location_area text
    check (location_area is null or char_length(location_area) between 1 and 80),
  add column location_spot text
    check (location_spot is null or char_length(location_spot) between 1 and 120),
  add column budget numeric(12, 2)
    check (budget is null or (budget > 0 and budget <= 100000000));

create table public.bucket_contributions (
  id         uuid primary key default gen_random_uuid(),
  item_id    uuid not null references public.bucket_items (id) on delete cascade,
  couple_id  uuid not null references public.couples (id) on delete cascade,
  author_id  uuid not null default auth.uid() references auth.users (id) on delete cascade,
  amount     numeric(12, 2) not null check (amount > 0 and amount <= 100000000),
  note       text check (note is null or char_length(note) <= 120),
  saved_on   date not null default current_date check (saved_on <= current_date + 1),
  created_at timestamptz not null default now()
);

create index bucket_contributions_item_idx on public.bucket_contributions (item_id);
create index bucket_contributions_couple_idx on public.bucket_contributions (couple_id);

alter table public.bucket_contributions enable row level security;

-- Entries are never edited: delete a wrong one and add it again.
revoke update on public.bucket_contributions from anon, authenticated;

-- Both partners see every entry for their couple's items.
create policy "contributions: couple read" on public.bucket_contributions
  for select to authenticated
  using (couple_id = public.my_couple_id());

-- You can only log savings as yourself, for an item in your own couple.
create policy "contributions: author insert" on public.bucket_contributions
  for insert to authenticated
  with check (
    couple_id = public.my_couple_id()
    and author_id = auth.uid()
    and exists (
      select 1 from public.bucket_items b
      where b.id = item_id and b.couple_id = public.my_couple_id()
    )
  );

-- You can only delete your own entries.
create policy "contributions: author delete" on public.bucket_contributions
  for delete to authenticated
  using (couple_id = public.my_couple_id() and author_id = auth.uid());


-- ---------------------------------------------------------------------------
-- 10. Profile birthday and profile photo (also in migrations/004).
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column birthday date
    check (birthday is null
           or (birthday >= date '1900-01-01' and birthday <= current_date + 1));

-- Allow people to change their own birthday (name and photo already allowed).
grant update (birthday) on public.profiles to authenticated;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

-- You and your partner can see each other's photo; nobody else can.
create policy "avatars: self and partner read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'avatars'
    and exists (
      select 1 from public.profiles p
      where p.user_id::text = (storage.foldername(name))[1]
        and (p.user_id = auth.uid()
             or (p.couple_id is not null and p.couple_id = public.my_couple_id()))
    )
  );

-- Only into your own folder.
create policy "avatars: own upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars'
              and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars: own delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = auth.uid()::text);


-- ---------------------------------------------------------------------------
-- 11. Photo upload limits enforced by Storage (also in migrations/005).
-- ---------------------------------------------------------------------------

update storage.buckets
   set file_size_limit = 5242880,  -- 5 MB
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
 where id = 'memory-photos';

update storage.buckets
   set file_size_limit = 5242880,
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
 where id = 'avatars';


-- ===========================================================================
-- 12. Week 3 (also in migrations/006)
-- ===========================================================================

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


-- ===========================================================================
-- 13. Love Notes and Time Capsules (also in migrations/007)
-- ===========================================================================

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


-- ===========================================================================
-- 14. Unlink from your partner (also in migrations/008)
-- ===========================================================================

create or replace function public.leave_couple()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  old_couple uuid;
  alphabet   text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  new_code   text;
  remaining  int;
begin
  if auth.uid() is null then
    raise exception 'Sign in first.';
  end if;

  old_couple := my_couple_id();
  if old_couple is null then
    raise exception 'You are not linked to a partner.';
  end if;

  update profiles set couple_id = null where user_id = auth.uid();

  select count(*) into remaining from profiles where couple_id = old_couple;

  if remaining = 0 then
    delete from couples where id = old_couple;   -- its rows go with it
  else
    loop
      new_code := '';
      for i in 1..6 loop
        new_code := new_code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
      end loop;
      exit when not exists (select 1 from couples where pairing_code = new_code);
    end loop;
    update couples set pairing_code = new_code where id = old_couple;
  end if;
end;
$$;

revoke execute on function public.leave_couple() from public, anon;
grant execute on function public.leave_couple() to authenticated;


-- ===========================================================================
-- 15. Your own memory tags (also in migrations/009)
-- ===========================================================================

create or replace function public.valid_memory_tags(t text[])
returns boolean
language sql
immutable
as $$
  select t is not null
     and coalesce(array_length(t, 1), 0) <= 10
     and not exists (
           select 1 from unnest(t) as x
            where x is null
               or char_length(x) not between 1 and 30
               or x <> btrim(x)
         )
$$;

-- Replace the old "only these six tags" check with the new rule.
do $$
declare
  c record;
begin
  for c in
    select conname
      from pg_constraint
     where conrelid = 'public.memories'::regclass
       and contype = 'c'
       and pg_get_constraintdef(oid) ilike '%tags%'
  loop
    execute format('alter table public.memories drop constraint %I', c.conname);
  end loop;
end;
$$;

alter table public.memories
  add constraint memories_tags_valid check (public.valid_memory_tags(tags));

-- Either partner may re-tag a memory in their couple.
create or replace function public.set_memory_tags(memory_id uuid, new_tags text[])
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not valid_memory_tags(coalesce(new_tags, '{}')) then
    raise exception 'Each tag must be 1 to 30 characters, and a memory can have up to 10 tags.';
  end if;
  update memories
     set tags = coalesce(new_tags, '{}')
   where id = memory_id
     and couple_id = my_couple_id();
  if not found then
    raise exception 'Memory not found.';
  end if;
end;
$$;

revoke execute on function public.set_memory_tags(uuid, text[]) from public, anon;
grant execute on function public.set_memory_tags(uuid, text[]) to authenticated;
