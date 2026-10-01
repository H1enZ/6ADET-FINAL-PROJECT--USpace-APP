-- =============================================================================
-- 009: Your own memory tags
--
-- Until now a memory could only have the six built-in tags. This lets a
-- couple type their own (e.g. "Outing", "Special date", "Monthsary"):
--   * each tag 1 to 30 characters, no leading or trailing spaces
--   * at most 10 tags per memory
-- and lets EITHER partner change a memory's tags, the same way either can
-- favourite it. Only the author can still change its photos, title or story.
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run.
-- Safe to run more than once.
-- =============================================================================

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
