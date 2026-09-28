-- =============================================================================
-- 003: bucket list details and a savings (sinking fund) log
--
-- Adds to each bucket list item (all optional):
--   location_area  Country / State, e.g. "Kyoto, Japan"
--   location_spot  The specific spot, e.g. "Arashiyama Bamboo Grove"
--   budget         The sinking-fund goal in pesos
--
-- Adds bucket_contributions: each time one partner puts money aside for an
-- item, they log it here. The app adds these up against the budget.
-- No real money moves through the app; this is a shared record.
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run.
-- (A brand-new project gets this from schema.sql, so skip it there.)
-- =============================================================================

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
