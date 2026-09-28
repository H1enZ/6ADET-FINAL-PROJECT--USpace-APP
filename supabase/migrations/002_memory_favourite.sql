-- =============================================================================
-- 002: either partner can favourite a memory
--
-- WHY: the memories policies let only the author change a memory, so a partner
-- could not tap the heart on the other person's memory. This function flips
-- ONLY is_favorite, and only for a memory in the caller's own couple.
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run.
-- (A brand-new project gets this from schema.sql, so skip it there.)
-- =============================================================================

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
