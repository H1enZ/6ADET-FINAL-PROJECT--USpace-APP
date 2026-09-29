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
