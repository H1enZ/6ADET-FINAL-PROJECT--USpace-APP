-- =============================================================================
-- 019: Timeline decorations, and the sticky-note frame
--
-- The shared scrapbook can now be decorated: sticky notes, stickers, washi
-- tape and doodles, placed, sized, turned and layered like the memories.
-- Both partners share them. Like 018 this is presentation only: no memory's
-- date, author, text or photos can be changed by anything here.
--
--   * timeline_decorations   one row per sticky note, sticker, tape or doodle.
--   * timeline_layout_items  its frame_style may now also be 'sticky' (the
--                            look of a memory without a photo).
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run.
-- Safe to run more than once. Needs 018.
-- =============================================================================

-- ------------------------------------------------------------- sticky frame

alter table public.timeline_layout_items
  drop constraint if exists timeline_layout_items_frame_style_check;
alter table public.timeline_layout_items
  add constraint timeline_layout_items_frame_style_check
  check (frame_style in ('polaroid', 'taped', 'film', 'paper', 'postcard',
                         'minimal', 'love_note', 'ticket', 'sticky'));

-- ------------------------------------------------------------- decorations

create table if not exists public.timeline_decorations (
  id         uuid primary key default gen_random_uuid(),
  couple_id  uuid not null references public.couples (id) on delete cascade,
  kind       text not null check (kind in ('sticky_note', 'sticker', 'tape', 'doodle')),
  -- Which sticker, tape pattern or doodle shape (names the app knows).
  variant    text not null check (char_length(variant) between 1 and 40),
  color      text check (color is null or color ~ '^#[0-9A-Fa-f]{6}$'),
  -- A sticky note's words (sticky notes only).
  body       text check (body is null or char_length(body) <= 200),
  -- A hand-drawn doodle's points (for a later freehand option; doodles only).
  points     jsonb check (points is null or (jsonb_typeof(points) = 'array'
                                             and jsonb_array_length(points) <= 600)),
  -- Board units, the same board as the memories.
  x          double precision not null check (x between -400 and 800),
  y          double precision not null check (y between -2000 and 200000),
  width      double precision not null check (width between 24 and 380),
  height     double precision not null check (height between 12 and 380),
  -- Tape may lie diagonally; the app keeps notes and stickers gentler.
  rotation   double precision not null default 0 check (rotation between -45 and 45),
  z_index    integer not null default 0 check (z_index between -100000 and 1000000),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint timeline_decorations_body_only_notes check ((kind = 'sticky_note') = (body is not null)),
  constraint timeline_decorations_points_only_doodles check (points is null or kind = 'doodle')
);

create index if not exists timeline_decorations_couple_idx
  on public.timeline_decorations (couple_id);

-- updated_at is stamped by the database on every change.
drop trigger if exists timeline_decorations_touch on public.timeline_decorations;
create trigger timeline_decorations_touch
  before insert or update on public.timeline_decorations
  for each row execute function public.timeline_touch();

-- A decoration stays with the couple it was made for.
create or replace function public.timeline_decoration_owner()
returns trigger language plpgsql as $$
begin
  if new.couple_id is distinct from old.couple_id then
    raise exception 'A decoration''s couple cannot be changed.';
  end if;
  return new;
end;
$$;

drop trigger if exists timeline_decorations_owner on public.timeline_decorations;
create trigger timeline_decorations_owner
  before update on public.timeline_decorations
  for each row execute function public.timeline_decoration_owner();

-- ------------------------------------------------------------- privileges + RLS

alter table public.timeline_decorations enable row level security;

revoke all on public.timeline_decorations from anon, public;
grant select, insert, update, delete on public.timeline_decorations to authenticated;
revoke execute on function public.timeline_decoration_owner() from public, anon, authenticated;

drop policy if exists "timeline decorations: couple read"   on public.timeline_decorations;
drop policy if exists "timeline decorations: couple insert" on public.timeline_decorations;
drop policy if exists "timeline decorations: couple update" on public.timeline_decorations;
drop policy if exists "timeline decorations: couple delete" on public.timeline_decorations;

create policy "timeline decorations: couple read" on public.timeline_decorations
  for select to authenticated using (couple_id = public.my_couple_id());
create policy "timeline decorations: couple insert" on public.timeline_decorations
  for insert to authenticated with check (couple_id = public.my_couple_id());
create policy "timeline decorations: couple update" on public.timeline_decorations
  for update to authenticated
  using (couple_id = public.my_couple_id())
  with check (couple_id = public.my_couple_id());
create policy "timeline decorations: couple delete" on public.timeline_decorations
  for delete to authenticated using (couple_id = public.my_couple_id());

-- ------------------------------------------------------------- realtime

do $rt$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and schemaname = 'public'
                       and tablename = 'timeline_decorations') then
    alter publication supabase_realtime add table public.timeline_decorations;
  end if;
end;
$rt$;
