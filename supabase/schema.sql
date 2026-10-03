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


-- ===========================================================================
-- 16. Both partners can edit a memory (also in migrations/010)
-- ===========================================================================

-- Memories: the couple may update; author and couple are locked by a trigger.
drop policy if exists "memories: author update" on public.memories;
drop policy if exists "memories: couple update" on public.memories;
create policy "memories: couple update" on public.memories
  for update to authenticated
  using (couple_id = public.my_couple_id())
  with check (couple_id = public.my_couple_id());

create or replace function public.keep_memory_owner()
returns trigger language plpgsql as $$
begin
  if new.author_id is distinct from old.author_id
     or new.couple_id is distinct from old.couple_id then
    raise exception 'A memory''s author and couple cannot be changed.';
  end if;
  return new;
end;
$$;

drop trigger if exists memories_keep_owner on public.memories;
create trigger memories_keep_owner
  before update on public.memories
  for each row execute function public.keep_memory_owner();

-- Memory photos: either partner may add or remove photos of their couple's
-- memories, only with files in their own couple's folder.
drop policy if exists "memory photos: author insert" on public.memory_photos;
drop policy if exists "memory photos: author delete" on public.memory_photos;
drop policy if exists "memory photos: couple insert" on public.memory_photos;
drop policy if exists "memory photos: couple delete" on public.memory_photos;

create policy "memory photos: couple insert" on public.memory_photos
  for insert to authenticated
  with check (
    couple_id = public.my_couple_id()
    and split_part(path, '/', 1) = public.my_couple_id()::text
    and exists (select 1 from public.memories m
                where m.id = memory_id and m.couple_id = public.my_couple_id())
  );

create policy "memory photos: couple delete" on public.memory_photos
  for delete to authenticated
  using (
    couple_id = public.my_couple_id()
    and exists (select 1 from public.memories m
                where m.id = memory_id and m.couple_id = public.my_couple_id())
  );


-- ===========================================================================
-- 17. Therabot, a private relationship reflection assistant (also in migrations/011)
--     Private answers are owner-only and deleted after 24 hours; finished
--     sessions stay as history; AI results are stored only by server-only
--     functions. Also replaces leave_couple() from section 14.
-- ===========================================================================
-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------

-- What BOTH partners may see. Never holds anyone's private answers.
-- expires_at is fixed at start + 24 hours and is never extended.
create table if not exists public.therabot_sessions (
  id                    uuid primary key default gen_random_uuid(),
  couple_id             uuid not null references public.couples (id) on delete cascade,
  started_by            uuid references auth.users (id) on delete set null,
  status                text not null default 'collecting'
                        check (status in ('collecting', 'reflecting', 'reflection_ready',
                                          'completed', 'closed')),
  title                 text check (title is null or char_length(title) between 1 and 60),
  shared_reflection     jsonb
                        check (shared_reflection is null or jsonb_typeof(shared_reflection) = 'object'),
  reflection_claimed_at timestamptz,
  reflection_attempts   smallint not null default 0 check (reflection_attempts between 0 and 3),
  created_at           timestamptz not null default now(),
  expires_at            timestamptz not null default now() + interval '24 hours',
  completed_at          timestamptz,
  updated_at            timestamptz not null default now(),
  check (expires_at = created_at + interval '24 hours'),
  -- a reflection exists exactly when the session reached reflection_ready
  check ((shared_reflection is not null) = (status in ('reflection_ready', 'completed'))),
  check ((completed_at is not null) = (status = 'completed'))
);

-- The two people in a session, fixed when it starts (so someone who joins
-- the couple later never sees it). Progress and choices are couple-visible.
create table if not exists public.therabot_participants (
  session_id          uuid not null references public.therabot_sessions (id) on delete cascade,
  user_id             uuid not null references auth.users (id) on delete cascade,
  progress            text not null default 'pending'
                      check (progress in ('pending', 'submitted', 'approved')),
  choice              text check (choice is null
                                  or choice in ('comfort', 'talk', 'space', 'reconnect')),
  delete_requested_at timestamptz,
  left_at             timestamptz,   -- set when this person left the couple; they lose access for good
  primary key (session_id, user_id),
  -- leaving counts as confirming deletion of the shared history
  check (left_at is null or delete_requested_at is not null)
);

-- One person's private perspective. Owner-only, deleted at expires_at.
create table if not exists public.therabot_submissions (
  id               uuid primary key default gen_random_uuid(),
  session_id       uuid not null,
  user_id          uuid not null references auth.users (id) on delete cascade,
  couple_id        uuid not null references public.couples (id) on delete cascade,
  expires_at       timestamptz not null,               -- copied from the session
  what_happened    text check (what_happened   is null or char_length(what_happened)   <= 2000),
  feelings         text check (feelings        is null or char_length(feelings)        <= 2000),
  wish_understood  text check (wish_understood is null or char_length(wish_understood) <= 2000),
  need_now         text check (need_now        is null or char_length(need_now)        <= 2000),
  context_used     jsonb not null default '{}'::jsonb check (jsonb_typeof(context_used) = 'object'),
  private_summary  jsonb check (private_summary is null or jsonb_typeof(private_summary) = 'object'),
  approved_summary text check (approved_summary is null
                               or char_length(approved_summary) between 1 and 1500),
  status           text not null default 'draft'
                   check (status in ('draft', 'summary_ready', 'approved', 'safety')),
  ai_attempts      smallint not null default 0 check (ai_attempts between 0 and 3),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (session_id, user_id),
  -- only a participant of the session can have a submission in it
  foreign key (session_id, user_id)
    references public.therabot_participants (session_id, user_id) on delete cascade,
  check (status in ('draft', 'safety') or private_summary is not null),
  check (status <> 'approved' or approved_summary is not null)
);

-- Completed sessions a person has hidden from their OWN history.
-- Read only through therabot_history(); the partner never sees it.
create table if not exists public.therabot_hidden (
  session_id uuid not null,
  user_id    uuid not null,
  hidden_at  timestamptz not null default now(),
  primary key (session_id, user_id),
  foreign key (session_id, user_id)
    references public.therabot_participants (session_id, user_id) on delete cascade
);

-- Long-term memory: only what a person chooses to save, kept until they
-- delete it. Never written by the server.
create table if not exists public.therabot_insights (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users (id) on delete cascade,
  body           text not null check (char_length(body) between 1 and 300 and btrim(body) <> ''),
  source_session uuid references public.therabot_sessions (id) on delete set null,
  created_at     timestamptz not null default now()
);


-- ---------------------------------------------------------------------------
-- 2. Indexes and triggers
-- ---------------------------------------------------------------------------

-- Only one open session per couple at a time.
create unique index if not exists therabot_sessions_one_open_idx
  on public.therabot_sessions (couple_id)
  where status in ('collecting', 'reflecting', 'reflection_ready');
create index if not exists therabot_sessions_couple_idx
  on public.therabot_sessions (couple_id, created_at desc);
create index if not exists therabot_sessions_expiry_idx
  on public.therabot_sessions (expires_at) where status <> 'completed';
create index if not exists therabot_participants_user_idx
  on public.therabot_participants (user_id);
create index if not exists therabot_submissions_user_idx
  on public.therabot_submissions (user_id);
create index if not exists therabot_submissions_expiry_idx
  on public.therabot_submissions (expires_at);
create index if not exists therabot_insights_user_idx
  on public.therabot_insights (user_id, created_at desc);

drop trigger if exists therabot_sessions_updated_at on public.therabot_sessions;
create trigger therabot_sessions_updated_at
  before update on public.therabot_sessions
  for each row execute function public.set_updated_at();

drop trigger if exists therabot_submissions_updated_at on public.therabot_submissions;
create trigger therabot_submissions_updated_at
  before update on public.therabot_submissions
  for each row execute function public.set_updated_at();

-- Up to 20 saved insights each. Checks the owner first, so nobody can count
-- someone else's insights by inserting with their id, and locks per person
-- so two saves at once can't pass 20.
create or replace function public.therabot_insights_cap()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null or new.user_id is distinct from auth.uid() then
    raise exception 'You can only save your own insights.';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('therabot_insights:' || new.user_id::text, 0));
  if (select count(*) from therabot_insights where user_id = new.user_id) >= 20 then
    raise exception 'You can keep up to 20 Therabot insights. Delete one to save another.';
  end if;
  return new;
end;
$$;

drop trigger if exists therabot_insights_cap on public.therabot_insights;
create trigger therabot_insights_cap
  before insert on public.therabot_insights
  for each row execute function public.therabot_insights_cap();


-- ---------------------------------------------------------------------------
-- 3. Helpers
-- ---------------------------------------------------------------------------

-- Can the signed-in person see this session? They must have taken part in
-- it, still be in its couple, and it must be open (under 24 hours) or have a
-- shared reflection (history). security definer so policies can call it
-- without the policies calling each other in a loop.
create or replace function public.therabot_visible(sid uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1
      from therabot_sessions s
      join therabot_participants p on p.session_id = s.id
     where s.id = sid
       and p.user_id = auth.uid() and p.left_at is null
       and s.couple_id = my_couple_id()
       and (s.expires_at > now() or s.shared_reflection is not null)
  )
$$;

-- The caller's session, locked for the rest of the transaction. Raises the
-- same message whether the session does not exist or belongs to someone
-- else, so nothing can be learned about other couples. Internal only.
create or replace function public.therabot_session_for_me(sid uuid)
returns public.therabot_sessions
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  s therabot_sessions;
begin
  if auth.uid() is null then
    raise exception 'Sign in first.';
  end if;
  select * into s
    from therabot_sessions
   where id = sid
     and couple_id = my_couple_id()
     and exists (select 1 from therabot_participants p
                  where p.session_id = sid and p.user_id = auth.uid()
                    and p.left_at is null)
     for update;
  if not found then
    raise exception 'Therabot session not found.';
  end if;
  return s;
end;
$$;

-- Deletes everything private that has passed its 24 hours. A reflection
-- nobody finished choosing on becomes history; sessions that never reached
-- a reflection (ended, closed, abandoned) are deleted. Works one session at
-- a time, locking the session before its submissions (the same order as
-- every other function), and skips sessions someone is using right now;
-- they are cleaned up next time and are already unreadable meanwhile.
-- Returns how many sessions it cleaned up.
create or replace function public.therabot_purge_expired()
returns integer language plpgsql security definer set search_path = public, pg_temp as $$
declare
  sid     uuid;
  cleaned integer := 0;
begin
  for sid in
    select s.id
      from therabot_sessions s
     where s.expires_at <= now()
       and (s.status <> 'completed'
            or exists (select 1 from therabot_submissions x where x.session_id = s.id))
     order by s.id
       for update skip locked
  loop
    delete from therabot_submissions where session_id = sid;
    update therabot_sessions
       set status = 'completed', completed_at = now(), reflection_claimed_at = null
     where id = sid and status = 'reflection_ready';
    delete from therabot_sessions where id = sid and status <> 'completed';
    cleaned := cleaned + 1;
  end loop;
  return cleaned;
end;
$$;


-- ---------------------------------------------------------------------------
-- 4. What people can do (signed-in users)
-- ---------------------------------------------------------------------------

-- Either partner starts a session. Needs both partners in the couple, no
-- other open session, and at most 3 sessions started in the last 24 hours.
create or replace function public.therabot_start()
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare
  me      uuid := auth.uid();
  c       uuid;
  members uuid[];
  recent  integer;
  new_id  uuid;
begin
  if me is null then
    raise exception 'Sign in first.';
  end if;
  c := my_couple_id();
  if c is null then
    raise exception 'Pair with your partner first.';
  end if;

  -- "for update" on the couple so two taps can't start two sessions at once
  perform 1 from couples where id = c for update;
  perform therabot_purge_expired();

  select array_agg(user_id) into members from profiles where couple_id = c;
  if coalesce(array_length(members, 1), 0) <> 2 then
    raise exception 'Therabot needs both partners in your space.';
  end if;

  if exists (select 1 from therabot_sessions
              where couple_id = c and status in ('collecting', 'reflecting', 'reflection_ready')) then
    raise exception 'A Therabot session is already open.';
  end if;

  select count(*) into recent from therabot_sessions
   where couple_id = c and created_at > now() - interval '24 hours';
  if recent >= 3 then
    raise exception 'You can start up to 3 Therabot sessions a day. Try again later.';
  end if;

  insert into therabot_sessions (couple_id, started_by) values (c, me) returning id into new_id;
  insert into therabot_participants (session_id, user_id) select new_id, unnest(members);
  return new_id;
end;
$$;

-- Saves (or replaces) your four answers. Any earlier AI draft is cleared,
-- because it no longer matches. Not allowed once you approved.
create or replace function public.therabot_save_answers(
  p_session_id      uuid,
  p_what_happened   text,
  p_feelings        text,
  p_wish_understood text,
  p_need_now        text
)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  s          therabot_sessions;
  old_status text;
  a1 text := nullif(btrim(coalesce(p_what_happened, '')), '');
  a2 text := nullif(btrim(coalesce(p_feelings, '')), '');
  a3 text := nullif(btrim(coalesce(p_wish_understood, '')), '');
  a4 text := nullif(btrim(coalesce(p_need_now, '')), '');
begin
  s := therabot_session_for_me(p_session_id);
  if s.status <> 'collecting' or s.expires_at <= now() then
    raise exception 'This Therabot session is no longer open.';
  end if;
  if a1 is null and a2 is null and a3 is null and a4 is null then
    raise exception 'Answer at least one question first.';
  end if;
  if greatest(char_length(a1), char_length(a2), char_length(a3), char_length(a4)) > 2000 then
    raise exception 'Each answer can be up to 2000 characters.';
  end if;

  select status into old_status from therabot_submissions
   where session_id = s.id and user_id = auth.uid()
     for update;
  if old_status in ('approved', 'safety') then
    raise exception 'Your answers can no longer be changed in this session.';
  end if;

  insert into therabot_submissions
         (session_id, user_id, couple_id, expires_at,
          what_happened, feelings, wish_understood, need_now)
  values (s.id, auth.uid(), s.couple_id, s.expires_at, a1, a2, a3, a4)
  on conflict (session_id, user_id) do update
     set what_happened    = excluded.what_happened,
         feelings         = excluded.feelings,
         wish_understood  = excluded.wish_understood,
         need_now         = excluded.need_now,
         status           = 'draft',
         private_summary  = null,
         approved_summary = null,
         context_used     = '{}'::jsonb;

  update therabot_participants set progress = 'pending'
   where session_id = s.id and user_id = auth.uid();
  update therabot_sessions set updated_at = now() where id = s.id;
end;
$$;

-- Approves your summary, as written or corrected by you. Returns true when
-- this was the second approval, so the shared reflection can be written.
-- The session row is locked first, so two approvals at the same instant
-- can't both miss each other.
create or replace function public.therabot_approve(p_session_id uuid, p_summary text)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare
  s        therabot_sessions;
  txt      text := btrim(coalesce(p_summary, ''));
  approved integer;
begin
  s := therabot_session_for_me(p_session_id);
  if s.status <> 'collecting' or s.expires_at <= now() then
    raise exception 'This Therabot session is no longer open.';
  end if;
  if char_length(txt) not between 1 and 1500 then
    raise exception 'Your summary must be 1 to 1500 characters.';
  end if;

  update therabot_submissions
     set status = 'approved', approved_summary = txt
   where session_id = s.id and user_id = auth.uid() and status = 'summary_ready';
  if not found then
    raise exception 'Review your summary before approving it.';
  end if;

  update therabot_participants set progress = 'approved'
   where session_id = s.id and user_id = auth.uid();

  select count(*) into approved from therabot_participants
   where session_id = s.id and progress = 'approved';
  if approved = 2 then
    update therabot_sessions set status = 'reflecting' where id = s.id;
    return true;
  end if;

  update therabot_sessions set updated_at = now() where id = s.id;
  return false;
end;
$$;

-- Your own next step. Partners choose independently; nothing requires the
-- choices to match. You can change yours until the 24 hours are up.
create or replace function public.therabot_choose(p_session_id uuid, p_choice text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  s therabot_sessions;
begin
  if p_choice is null or p_choice not in ('comfort', 'talk', 'space', 'reconnect') then
    raise exception 'Choose Comfort, Talk, Take Space or Reconnect.';
  end if;
  s := therabot_session_for_me(p_session_id);
  if s.status not in ('reflection_ready', 'completed') or s.expires_at <= now() then
    raise exception 'Next steps can only be chosen on an open reflection.';
  end if;

  update therabot_participants set choice = p_choice
   where session_id = s.id and user_id = auth.uid();

  if s.status = 'reflection_ready'
     and not exists (select 1 from therabot_participants
                      where session_id = s.id and choice is null) then
    update therabot_sessions set status = 'completed', completed_at = now() where id = s.id;
  else
    update therabot_sessions set updated_at = now() where id = s.id;
  end if;
end;
$$;

-- Either partner may end a session before its reflection is ready. No
-- reason is stored. Private answers still follow the 24-hour rule.
create or replace function public.therabot_end(p_session_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  s therabot_sessions;
begin
  s := therabot_session_for_me(p_session_id);
  if s.status not in ('collecting', 'reflecting') or s.expires_at <= now() then
    raise exception 'This Therabot session can''t be ended now.';
  end if;
  update therabot_sessions set status = 'closed', reflection_claimed_at = null where id = s.id;
end;
$$;

-- Deletes YOUR answers, draft and summary in a session, immediately. Always
-- allowed: no status, expiry or partner can block it. A session that has
-- not reached its reflection yet can't finish without them, so it is closed
-- (which also means answers can't be deleted and re-saved to get more AI
-- attempts). A reflection that already exists is not affected.
create or replace function public.therabot_delete_my_answers(p_session_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'Sign in first.';
  end if;
  if not exists (select 1 from therabot_submissions
                  where session_id = p_session_id and user_id = me) then
    return;                                   -- nothing of yours is there
  end if;

  -- lock the session first (same order as the other functions)
  perform 1 from therabot_sessions where id = p_session_id for update;

  delete from therabot_submissions where session_id = p_session_id and user_id = me;

  update therabot_sessions set status = 'closed', reflection_claimed_at = null
   where id = p_session_id and status in ('collecting', 'reflecting');
end;
$$;

-- An optional, generic title. It can be changed only while the session is
-- open; once it is completed history, the title is frozen for both.
create or replace function public.therabot_set_title(p_session_id uuid, p_title text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  s therabot_sessions;
  t text := nullif(btrim(coalesce(p_title, '')), '');
begin
  s := therabot_session_for_me(p_session_id);
  if s.status not in ('collecting', 'reflecting', 'reflection_ready') or s.expires_at <= now() then
    raise exception 'The title can only be changed while the session is open.';
  end if;
  if char_length(t) > 60 then
    raise exception 'A title can be up to 60 characters.';
  end if;
  update therabot_sessions set title = t where id = s.id;
end;
$$;

-- Hides (or un-hides) a finished session from YOUR history only. Your
-- partner still sees it and is not told.
create or replace function public.therabot_set_hidden(p_session_id uuid, p_hidden boolean)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  s therabot_sessions;
begin
  s := therabot_session_for_me(p_session_id);
  if not (s.status = 'completed' or (s.status = 'reflection_ready' and s.expires_at <= now())) then
    raise exception 'Only finished sessions can be hidden.';
  end if;
  if coalesce(p_hidden, true) then
    insert into therabot_hidden (session_id, user_id) values (s.id, auth.uid())
    on conflict (session_id, user_id) do nothing;
  else
    delete from therabot_hidden where session_id = s.id and user_id = auth.uid();
  end if;
end;
$$;

-- Asks for (or withdraws) permanent deletion of a finished session. It is
-- deleted for both only when EVERY participant has confirmed. Returns true
-- when it was deleted.
create or replace function public.therabot_request_delete(p_session_id uuid, p_confirm boolean)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare
  s therabot_sessions;
begin
  s := therabot_session_for_me(p_session_id);
  if not (s.status = 'completed' or (s.status = 'reflection_ready' and s.expires_at <= now())) then
    raise exception 'Only finished sessions can be deleted from your history.';
  end if;

  update therabot_participants
     set delete_requested_at = case when coalesce(p_confirm, true) then now() end
   where session_id = s.id and user_id = auth.uid();

  if coalesce(p_confirm, true)
     and not exists (select 1 from therabot_participants
                      where session_id = s.id and delete_requested_at is null) then
    delete from therabot_sessions where id = s.id;
    return true;
  end if;

  update therabot_sessions set updated_at = now() where id = s.id;
  return false;
end;
$$;

-- The couple's current session (any status, under 24 hours), described
-- from the caller's side: "me" and "partner", no user ids.
-- my_partner_number is 1 for whoever started it, 2 for the other; the
-- shared reflection refers to people only as Partner 1 and Partner 2.
create or replace function public.therabot_current()
returns table (
  session_id        uuid,
  status            text,
  i_started         boolean,
  my_partner_number smallint,
  my_progress       text,
  partner_progress  text,
  my_choice         text,
  partner_choice    text,
  title             text,
  shared_reflection jsonb,
  created_at        timestamptz,
  expires_at        timestamptz
)
language sql stable security definer set search_path = public, pg_temp as $$
  select s.id,
         s.status,
         s.started_by is not distinct from auth.uid(),
         (case when s.started_by = auth.uid() then 1 else 2 end)::smallint,
         mine.progress,
         theirs.progress,
         mine.choice,
         theirs.choice,
         s.title,
         s.shared_reflection,
         s.created_at,
         s.expires_at
    from therabot_sessions s
    join therabot_participants mine
      on mine.session_id = s.id and mine.user_id = auth.uid() and mine.left_at is null
    left join therabot_participants theirs
      on theirs.session_id = s.id and theirs.user_id <> auth.uid()
   where s.couple_id = my_couple_id()
     and s.expires_at > now()
   order by s.created_at desc
   limit 1
$$;

-- Finished sessions for the caller, newest first, without the ones they
-- hid (unless include_hidden). Contains no private answers or summaries.
create or replace function public.therabot_history(include_hidden boolean default false)
returns table (
  session_id               uuid,
  title                    text,
  shared_reflection        jsonb,
  my_partner_number        smallint,
  my_choice                text,
  partner_choice           text,
  i_requested_delete       boolean,
  partner_requested_delete boolean,
  is_hidden                boolean,
  created_at               timestamptz,
  completed_at             timestamptz
)
language sql stable security definer set search_path = public, pg_temp as $$
  select s.id,
         s.title,
         s.shared_reflection,
         (case when s.started_by = auth.uid() then 1 else 2 end)::smallint,
         mine.choice,
         theirs.choice,
         mine.delete_requested_at is not null,
         coalesce(theirs.delete_requested_at is not null, false),
         h.session_id is not null,
         s.created_at,
         coalesce(s.completed_at, s.expires_at)
    from therabot_sessions s
    join therabot_participants mine
      on mine.session_id = s.id and mine.user_id = auth.uid() and mine.left_at is null
    left join therabot_participants theirs
      on theirs.session_id = s.id and theirs.user_id <> auth.uid()
    left join therabot_hidden h
      on h.session_id = s.id and h.user_id = auth.uid()
   where s.couple_id = my_couple_id()
     and (s.status = 'completed' or (s.status = 'reflection_ready' and s.expires_at <= now()))
     and (include_hidden or h.session_id is null)
   order by s.created_at desc
$$;


-- ---------------------------------------------------------------------------
-- 5. Server-only functions (service_role, used by the Edge Function).
--    The app can never call these, so it can't fake an AI summary, a
--    safety result, both-approved, or a shared reflection.
-- ---------------------------------------------------------------------------

-- Stores the AI's private summary for one submission, or marks it as a
-- safety case. A safety case closes the session; the reason stays on the
-- owner's private row and nowhere the partner can read.
-- Uses up one of the 3 AI summaries BEFORE the AI is called, so a call that
-- fails (or a burst of parallel calls) still counts and can't be repeated
-- for free. Returns the row's new version (updated_at); the summary can only
-- be stored against that same version, so answers saved meanwhile win.
create or replace function public.therabot_reserve_summary_attempt(p_submission_id uuid)
returns timestamptz language plpgsql security definer set search_path = public, pg_temp as $$
declare
  sid     uuid;
  s       therabot_sessions;
  sub     therabot_submissions;
  version timestamptz;
begin
  select session_id into sid from therabot_submissions where id = p_submission_id;
  if sid is null then
    raise exception 'Submission not found.';
  end if;
  select * into s from therabot_sessions where id = sid for update;
  if not found then
    raise exception 'Submission not found.';
  end if;
  select * into sub from therabot_submissions where id = p_submission_id for update;
  if not found then
    raise exception 'Submission not found.';
  end if;

  if s.status <> 'collecting' or s.expires_at <= now() then
    raise exception 'This Therabot session is no longer open.';
  end if;
  if sub.status not in ('draft', 'summary_ready') then
    raise exception 'This summary can no longer be changed.';
  end if;
  if sub.ai_attempts >= 3 then
    raise exception 'The summary limit for this session has been reached.';
  end if;

  update therabot_submissions set ai_attempts = ai_attempts + 1
   where id = sub.id
  returning updated_at into version;
  return version;
end;
$$;

create or replace function public.therabot_store_summary(
  p_submission_id uuid,
  p_version       timestamptz,
  p_summary       jsonb,
  p_context       jsonb,
  p_flagged       boolean
)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  sid uuid;
  s   therabot_sessions;
  sub therabot_submissions;
begin
  select session_id into sid from therabot_submissions where id = p_submission_id;
  if sid is null then
    raise exception 'Submission not found.';
  end if;
  select * into s from therabot_sessions where id = sid for update;
  if not found then
    raise exception 'Submission not found.';
  end if;
  select * into sub from therabot_submissions where id = p_submission_id for update;
  if not found then
    raise exception 'Submission not found.';         -- deleted by its owner meanwhile
  end if;

  if s.status <> 'collecting' or s.expires_at <= now() then
    raise exception 'This Therabot session is no longer open.';
  end if;
  if sub.status not in ('draft', 'summary_ready') then
    raise exception 'This summary can no longer be changed.';
  end if;
  if p_version is null or sub.updated_at is distinct from p_version then
    raise exception 'Your answers changed while Therabot was writing. Ask for a new summary.';
  end if;
  if p_summary is null or jsonb_typeof(p_summary) <> 'object' then
    raise exception 'Invalid summary.';
  end if;
  if p_context is not null and jsonb_typeof(p_context) <> 'object' then
    raise exception 'Invalid context.';
  end if;

  update therabot_submissions
     set status           = case when coalesce(p_flagged, true) then 'safety' else 'summary_ready' end,
         private_summary  = p_summary,
         approved_summary = null,
         context_used     = coalesce(p_context, '{}'::jsonb)
   where id = sub.id;

  if coalesce(p_flagged, true) then
    update therabot_sessions set status = 'closed', reflection_claimed_at = null where id = s.id;
  else
    update therabot_participants set progress = 'submitted'
     where session_id = s.id and user_id = sub.user_id;
    update therabot_sessions set updated_at = now() where id = s.id;
  end if;
end;
$$;

-- Lets exactly one server call write the reflection at a time, and at most
-- 3 tries per session (each try may ask the AI twice). A claim older than
-- 90 seconds (a crashed call) can be taken over. Returns the claim token
-- (null when refused); only its holder can store or release.
create or replace function public.therabot_claim_reflection(p_session_id uuid)
returns timestamptz language plpgsql security definer set search_path = public, pg_temp as $$
declare
  token timestamptz;
begin
  update therabot_sessions
     set reflection_claimed_at = clock_timestamp(),
         reflection_attempts   = reflection_attempts + 1
   where id = p_session_id
     and status = 'reflecting'
     and expires_at > now()
     and reflection_attempts < 3
     and (reflection_claimed_at is null or reflection_claimed_at < now() - interval '90 seconds')
  returning reflection_claimed_at into token;
  return token;
end;
$$;

-- Gives the claim back after a failed try, so the couple can retry at once.
-- Only the holder of the current claim can release it: a slow, earlier
-- request can't release a newer request's claim.
create or replace function public.therabot_release_reflection(p_session_id uuid, p_claim timestamptz)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update therabot_sessions
     set reflection_claimed_at = null
   where id = p_session_id
     and status = 'reflecting'
     and reflection_claimed_at = p_claim;
end;
$$;

-- The ONLY input the shared reflection may use: both APPROVED summaries,
-- labelled Partner 1 (who started) and Partner 2. Nothing is returned
-- unless both partners approved and the session is waiting for it.
create or replace function public.therabot_reflection_input(p_session_id uuid)
returns table (partner smallint, approved_summary text)
language sql stable security definer set search_path = public, pg_temp as $$
  select (case when sub.user_id = s.started_by then 1 else 2 end)::smallint,
         sub.approved_summary
    from therabot_sessions s
    join therabot_submissions sub on sub.session_id = s.id
   where s.id = p_session_id
     and s.status = 'reflecting'
     and s.expires_at > now()
     and sub.status = 'approved'
     and (select count(*) from therabot_submissions x
           where x.session_id = s.id and x.status = 'approved') = 2
   order by 1
$$;

-- Stores the shared reflection (or closes the session if the safety check
-- flagged it). Only by the request that holds the CURRENT claim, and only
-- when both approved.
create or replace function public.therabot_store_reflection(
  p_session_id uuid,
  p_claim      timestamptz,
  p_reflection jsonb,
  p_title      text,
  p_flagged    boolean
)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  s therabot_sessions;
  t text := left(nullif(btrim(coalesce(p_title, '')), ''), 60);
begin
  select * into s from therabot_sessions where id = p_session_id for update;
  if not found then
    raise exception 'Therabot session not found.';
  end if;
  if s.status <> 'reflecting' or s.expires_at <= now()
     or p_claim is null or s.reflection_claimed_at is distinct from p_claim then
    raise exception 'This session is not waiting for a reflection.';
  end if;
  if (select count(*) from therabot_submissions
       where session_id = s.id and status = 'approved') <> 2 then
    raise exception 'Both partners must approve their summaries first.';
  end if;

  if coalesce(p_flagged, true) then
    update therabot_sessions set status = 'closed', reflection_claimed_at = null where id = s.id;
    return;
  end if;
  if p_reflection is null or jsonb_typeof(p_reflection) <> 'object' then
    raise exception 'Invalid reflection.';
  end if;

  update therabot_sessions
     set status                = 'reflection_ready',
         shared_reflection     = p_reflection,
         title                 = coalesce(s.title, t),
         reflection_claimed_at = null
   where id = s.id;
end;
$$;


-- ---------------------------------------------------------------------------
-- 6. Table permissions and row-level security
-- ---------------------------------------------------------------------------

alter table public.therabot_sessions     enable row level security;
alter table public.therabot_participants enable row level security;
alter table public.therabot_submissions  enable row level security;
alter table public.therabot_hidden       enable row level security;
alter table public.therabot_insights     enable row level security;

-- Start from nothing, then allow only what is needed. All writes to
-- sessions, participants, submissions and hidden go through the functions.
revoke all on public.therabot_sessions     from anon, authenticated;
revoke all on public.therabot_participants from anon, authenticated;
revoke all on public.therabot_submissions  from anon, authenticated;
revoke all on public.therabot_hidden       from anon, authenticated;
revoke all on public.therabot_insights     from anon, authenticated;

grant select on public.therabot_sessions     to authenticated;
grant select on public.therabot_participants to authenticated;
grant select on public.therabot_submissions  to authenticated;
grant select, insert, delete on public.therabot_insights to authenticated;
-- therabot_hidden: no direct access at all (RLS on, no policy, no grant).

-- Sessions and participants: only people who took part, still in that
-- couple, while open or as history.
drop policy if exists "therabot sessions: participants read" on public.therabot_sessions;
create policy "therabot sessions: participants read" on public.therabot_sessions
  for select to authenticated
  using (public.therabot_visible(id));

drop policy if exists "therabot participants: participants read" on public.therabot_participants;
create policy "therabot participants: participants read" on public.therabot_participants
  for select to authenticated
  using (public.therabot_visible(session_id));

-- Submissions: the owner only, and only for 24 hours. There is no partner
-- branch, not even after both approve.
drop policy if exists "therabot submissions: owner only" on public.therabot_submissions;
create policy "therabot submissions: owner only" on public.therabot_submissions
  for select to authenticated
  using (user_id = auth.uid()
         and couple_id = public.my_couple_id()
         and expires_at > now());

-- Insights: the owner reads, saves and deletes their own. No editing.
drop policy if exists "therabot insights: owner read" on public.therabot_insights;
create policy "therabot insights: owner read" on public.therabot_insights
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "therabot insights: owner save" on public.therabot_insights;
create policy "therabot insights: owner save" on public.therabot_insights
  for insert to authenticated
  with check (user_id = auth.uid()
              and (source_session is null or public.therabot_visible(source_session)));

drop policy if exists "therabot insights: owner delete" on public.therabot_insights;
create policy "therabot insights: owner delete" on public.therabot_insights
  for delete to authenticated using (user_id = auth.uid());


-- ---------------------------------------------------------------------------
-- 7. Function permissions
-- ---------------------------------------------------------------------------

-- Signed-in users.
revoke execute on function public.therabot_visible(uuid) from public, anon;
revoke execute on function public.therabot_start() from public, anon;
revoke execute on function public.therabot_save_answers(uuid, text, text, text, text) from public, anon;
revoke execute on function public.therabot_approve(uuid, text) from public, anon;
revoke execute on function public.therabot_choose(uuid, text) from public, anon;
revoke execute on function public.therabot_end(uuid) from public, anon;
revoke execute on function public.therabot_delete_my_answers(uuid) from public, anon;
revoke execute on function public.therabot_set_title(uuid, text) from public, anon;
revoke execute on function public.therabot_set_hidden(uuid, boolean) from public, anon;
revoke execute on function public.therabot_request_delete(uuid, boolean) from public, anon;
revoke execute on function public.therabot_current() from public, anon;
revoke execute on function public.therabot_history(boolean) from public, anon;
grant execute on function public.therabot_visible(uuid) to authenticated;
grant execute on function public.therabot_start() to authenticated;
grant execute on function public.therabot_save_answers(uuid, text, text, text, text) to authenticated;
grant execute on function public.therabot_approve(uuid, text) to authenticated;
grant execute on function public.therabot_choose(uuid, text) to authenticated;
grant execute on function public.therabot_end(uuid) to authenticated;
grant execute on function public.therabot_delete_my_answers(uuid) to authenticated;
grant execute on function public.therabot_set_title(uuid, text) to authenticated;
grant execute on function public.therabot_set_hidden(uuid, boolean) to authenticated;
grant execute on function public.therabot_request_delete(uuid, boolean) to authenticated;
grant execute on function public.therabot_current() to authenticated;
grant execute on function public.therabot_history(boolean) to authenticated;

-- Internal and server-only: never callable from the app.
revoke execute on function public.therabot_session_for_me(uuid) from public, anon, authenticated;
revoke execute on function public.therabot_insights_cap() from public, anon, authenticated;
revoke execute on function public.therabot_purge_expired() from public, anon, authenticated;
revoke execute on function public.therabot_store_summary(uuid, timestamptz, jsonb, jsonb, boolean) from public, anon, authenticated;
revoke execute on function public.therabot_claim_reflection(uuid) from public, anon, authenticated;
revoke execute on function public.therabot_reserve_summary_attempt(uuid) from public, anon, authenticated;
revoke execute on function public.therabot_release_reflection(uuid, timestamptz) from public, anon, authenticated;
revoke execute on function public.therabot_reflection_input(uuid) from public, anon, authenticated;
revoke execute on function public.therabot_store_reflection(uuid, timestamptz, jsonb, text, boolean) from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.therabot_purge_expired() to service_role;
    grant execute on function public.therabot_store_summary(uuid, timestamptz, jsonb, jsonb, boolean) to service_role;
    grant execute on function public.therabot_claim_reflection(uuid) to service_role;
    grant execute on function public.therabot_reserve_summary_attempt(uuid) to service_role;
    grant execute on function public.therabot_release_reflection(uuid, timestamptz) to service_role;
    grant execute on function public.therabot_reflection_input(uuid) to service_role;
    grant execute on function public.therabot_store_reflection(uuid, timestamptz, jsonb, text, boolean) to service_role;
  end if;
end;
$$;


-- ---------------------------------------------------------------------------
-- 8. Leaving your partner also ends any Therabot session still collecting
--    answers and deletes your own private Therabot answers. Finished history
--    (and a reflection you both received) stays with the partner who
--    remains, like the rest of the couple's space; you lose access to it, and
--    your leaving counts as your confirmation to delete it.
-- ---------------------------------------------------------------------------

create or replace function public.leave_couple()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
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

  -- Lock the couple first (as therabot_start does), so a session can't be
  -- started with you in it while you are leaving. Then lock the couple's
  -- Therabot sessions before touching their submissions or participants,
  -- the same order every other function uses, so leaving can't deadlock
  -- with your partner deleting a history entry at the same moment.
  perform 1 from couples where id = old_couple for update;
  perform 1 from therabot_sessions where couple_id = old_couple order by id for update;

  -- Therabot: a session still collecting answers ends; a reflection you
  -- both already received is kept as history (as at the 24-hour mark); your
  -- own private answers are deleted everywhere.
  delete from therabot_sessions
   where couple_id = old_couple and status in ('collecting', 'reflecting', 'closed');
  update therabot_sessions
     set status = 'completed', completed_at = now(), reflection_claimed_at = null
   where couple_id = old_couple and status = 'reflection_ready';
  delete from therabot_submissions where user_id = auth.uid();

  -- In the history that stays, you lose access for good (even if you rejoin
  -- later), and leaving counts as your confirmation to delete it, so your
  -- former partner can delete it on their own if they want to.
  update therabot_participants p
     set left_at = now(),
         delete_requested_at = coalesce(p.delete_requested_at, now())
    from therabot_sessions s
   where s.id = p.session_id
     and s.couple_id = old_couple
     and p.user_id = auth.uid();

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


-- ---------------------------------------------------------------------------
-- 9. The hourly clean-up
--    (Therabot tables are deliberately NOT added to Realtime: Supabase
--    sends delete events to every subscriber without applying row-level
--    security, which would show other couples when sessions end. The app
--    refreshes with therabot_current() instead.)
-- ---------------------------------------------------------------------------

-- If the pg_cron extension is turned on (Database > Extensions), delete
-- expired private material every hour. Without it, nothing expired can be
-- read anyway (see the policies), and the clean-up also runs whenever a
-- session is started.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    execute $cron$
      select cron.schedule('therabot-purge-expired', '17 * * * *',
                           'select public.therabot_purge_expired()')
    $cron$;
  end if;
end;
$$;


-- ===========================================================================
-- 18. Mood set for the redesigned Home screen (also in migrations/012)
-- ===========================================================================
-- The eight Home moods; the older values stay allowed for history.
alter table public.moods drop constraint if exists moods_mood_check;
alter table public.moods add constraint moods_mood_check check (mood in (
  -- Offered by the app (the eight Home moods)
  'loved', 'happy', 'calm', 'emotional', 'need_a_hug', 'flirty', 'romantic', 'excited',
  -- History only: allowed so older check-ins stay valid
  'relaxed', 'tired', 'stressed', 'sad', 'anxious', 'lonely', 'upset'
));
