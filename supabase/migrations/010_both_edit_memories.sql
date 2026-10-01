-- =============================================================================
-- 010: Both partners can edit a memory
--
-- Until now only the person who added a memory could change it. Now EITHER
-- partner can edit its title, story, place, date and photos.
--   * Deleting a whole memory stays with its author.
--   * Nobody can change who added a memory, or move it to another couple.
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run.
-- Safe to run more than once.
-- =============================================================================

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
