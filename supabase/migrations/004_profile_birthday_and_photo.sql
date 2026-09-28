-- =============================================================================
-- 004: profile birthday and profile photo
--
-- profiles.birthday   optional; only you can change yours, and only you and
--                     your partner can see it (the profiles policies already
--                     limit who can read a profile).
-- avatars bucket      private. Each person uploads into a folder named after
--                     their own user id. Only you and your partner can view it.
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run.
-- (A brand-new project gets this from schema.sql, so skip it there.)
-- =============================================================================

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
