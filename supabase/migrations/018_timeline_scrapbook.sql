-- =============================================================================
-- 018: Timeline scrapbook layout (presentation only)
--
-- The Timeline can now be arranged by hand like a real scrapbook: where each
-- memory sits, its size, tilt, frame style and layer, and which memories are
-- joined by a small decorative line. Both partners share one arrangement.
--
-- This is PRESENTATION data only. The memories themselves (their dates,
-- authors, text and photos) are not touched: `memories` and `memory_photos`
-- are unchanged, and nothing here can change a memory's date or owner.
--
--   * timeline_layout_items   one row per placed memory (position, size,
--                             tilt, frame, layer). No row = automatic layout.
--   * timeline_connections    a visual line between two memories.
--
-- Both partners of a couple can read and change both tables, only for their
-- own couple's memories. Deleting a memory removes its row and lines.
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run.
-- Safe to run more than once.
-- =============================================================================

-- ------------------------------------------------------------- layout items

create table if not exists public.timeline_layout_items (
  memory_id   uuid primary key references public.memories (id) on delete cascade,
  couple_id   uuid not null references public.couples (id) on delete cascade,
  -- Canvas units: the scrapbook is 400 units wide on every phone.
  x           double precision not null check (x between -400 and 800),
  y           double precision not null check (y between -2000 and 200000),
  width       double precision not null check (width between 90 and 380),
  -- A gentle scrapbook tilt, never upside down.
  rotation    double precision not null default 0 check (rotation between -6 and 6),
  -- null = the automatic look for that memory.
  frame_style text check (frame_style in ('polaroid', 'taped', 'film', 'paper',
                                          'postcard', 'minimal', 'love_note', 'ticket')),
  z_index     integer not null default 0 check (z_index between -100000 and 100000),
  updated_at  timestamptz not null default now(),
  updated_by  uuid default auth.uid() references auth.users (id) on delete set null
);

create index if not exists timeline_layout_items_couple_idx
  on public.timeline_layout_items (couple_id);

-- ------------------------------------------------------------- connections

create table if not exists public.timeline_connections (
  id         uuid primary key default gen_random_uuid(),
  couple_id  uuid not null references public.couples (id) on delete cascade,
  source_id  uuid not null references public.memories (id) on delete cascade,
  target_id  uuid not null references public.memories (id) on delete cascade,
  style      text not null default 'dotted' check (style in ('dotted', 'ribbon', 'hearts')),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint timeline_connections_not_self check (source_id <> target_id)
);

-- One line per pair of memories, whichever way round it was drawn.
create unique index if not exists timeline_connections_pair_idx
  on public.timeline_connections (least(source_id, target_id), greatest(source_id, target_id));
create index if not exists timeline_connections_couple_idx
  on public.timeline_connections (couple_id);

-- ------------------------------------------------------------- triggers

-- Every change stamps updated_at (and who made it) in the database, so the
-- app never has to supply it.
create or replace function public.timeline_touch()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  if tg_table_name = 'timeline_layout_items' then
    new.updated_by := coalesce(auth.uid(), new.updated_by);
  end if;
  return new;
end;
$$;

drop trigger if exists timeline_layout_items_touch on public.timeline_layout_items;
create trigger timeline_layout_items_touch
  before insert or update on public.timeline_layout_items
  for each row execute function public.timeline_touch();

drop trigger if exists timeline_connections_touch on public.timeline_connections;
create trigger timeline_connections_touch
  before insert or update on public.timeline_connections
  for each row execute function public.timeline_touch();

-- A row always belongs to the couple of the memories it is about, and which
-- memories (and couple) a row is about can never be changed afterwards.
create or replace function public.timeline_check_owner()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  -- (Nested ifs: PL/pgSQL does not skip the rest of an "and", so a column
  -- only one of the tables has must never be read for the other.)
  if tg_op = 'UPDATE' then
    if new.couple_id is distinct from old.couple_id then
      raise exception 'A scrapbook item''s couple cannot be changed.';
    end if;
    if tg_table_name = 'timeline_layout_items' then
      if new.memory_id is distinct from old.memory_id then
        raise exception 'A scrapbook item''s memory cannot be changed.';
      end if;
    else
      if new.source_id is distinct from old.source_id
         or new.target_id is distinct from old.target_id then
        raise exception 'A connection''s memories cannot be changed.';
      end if;
    end if;
  end if;

  if tg_table_name = 'timeline_layout_items' then
    if not exists (select 1 from memories m
                   where m.id = new.memory_id and m.couple_id = new.couple_id) then
      raise exception 'That memory is not in this scrapbook.';
    end if;
  else
    if (select count(*) from memories m
        where m.id in (new.source_id, new.target_id)
          and m.couple_id = new.couple_id) <> 2 then
      raise exception 'Both memories must be in this scrapbook.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists timeline_layout_items_owner on public.timeline_layout_items;
create trigger timeline_layout_items_owner
  before insert or update on public.timeline_layout_items
  for each row execute function public.timeline_check_owner();

drop trigger if exists timeline_connections_owner on public.timeline_connections;
create trigger timeline_connections_owner
  before insert or update on public.timeline_connections
  for each row execute function public.timeline_check_owner();

-- ------------------------------------------------------------- privileges + RLS

alter table public.timeline_layout_items enable row level security;
alter table public.timeline_connections  enable row level security;

revoke all on public.timeline_layout_items from anon, public;
revoke all on public.timeline_connections  from anon, public;
grant select, insert, update, delete on public.timeline_layout_items to authenticated;
grant select, insert, update, delete on public.timeline_connections  to authenticated;
revoke execute on function public.timeline_check_owner() from public, anon, authenticated;
revoke execute on function public.timeline_touch()       from public, anon, authenticated;

-- Both partners share the scrapbook: read and change only their own couple's
-- rows, and only about their own couple's memories.
drop policy if exists "timeline layout: couple read"   on public.timeline_layout_items;
drop policy if exists "timeline layout: couple insert" on public.timeline_layout_items;
drop policy if exists "timeline layout: couple update" on public.timeline_layout_items;
drop policy if exists "timeline layout: couple delete" on public.timeline_layout_items;

create policy "timeline layout: couple read" on public.timeline_layout_items
  for select to authenticated using (couple_id = public.my_couple_id());
create policy "timeline layout: couple insert" on public.timeline_layout_items
  for insert to authenticated
  with check (
    couple_id = public.my_couple_id()
    and exists (select 1 from public.memories m
                where m.id = memory_id and m.couple_id = public.my_couple_id())
  );
create policy "timeline layout: couple update" on public.timeline_layout_items
  for update to authenticated
  using (couple_id = public.my_couple_id())
  with check (couple_id = public.my_couple_id());
create policy "timeline layout: couple delete" on public.timeline_layout_items
  for delete to authenticated using (couple_id = public.my_couple_id());

drop policy if exists "timeline connections: couple read"   on public.timeline_connections;
drop policy if exists "timeline connections: couple insert" on public.timeline_connections;
drop policy if exists "timeline connections: couple update" on public.timeline_connections;
drop policy if exists "timeline connections: couple delete" on public.timeline_connections;

create policy "timeline connections: couple read" on public.timeline_connections
  for select to authenticated using (couple_id = public.my_couple_id());
create policy "timeline connections: couple insert" on public.timeline_connections
  for insert to authenticated
  with check (
    couple_id = public.my_couple_id()
    and exists (select 1 from public.memories m
                where m.id = source_id and m.couple_id = public.my_couple_id())
    and exists (select 1 from public.memories m
                where m.id = target_id and m.couple_id = public.my_couple_id())
  );
create policy "timeline connections: couple update" on public.timeline_connections
  for update to authenticated
  using (couple_id = public.my_couple_id())
  with check (couple_id = public.my_couple_id());
create policy "timeline connections: couple delete" on public.timeline_connections
  for delete to authenticated using (couple_id = public.my_couple_id());

-- ------------------------------------------------------------- realtime

-- Changes appear on the partner's phone without refreshing (RLS still
-- decides who receives what).
do $rt$
declare t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['timeline_layout_items', 'timeline_connections'] loop
      if not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime'
                       and schemaname = 'public' and tablename = t) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end;
$rt$;
