-- =============================================================================
-- 011: Therabot, a private relationship reflection assistant (database only)
--
-- Each partner privately answers four questions and approves an AI summary.
-- Only after BOTH approve does the server write a shared reflection, built
-- from the approved summaries. Each partner then chooses their own next step.
--
-- THE RULES this file enforces in the database, whatever the app does:
--   * A person's answers, AI draft and approved summary (therabot_submissions)
--     are readable ONLY by that person. The partner never gets the row.
--   * Private material lasts 24 hours from the session's start, then it is
--     deleted. Anyone can delete their own answers sooner, at any time.
--   * A completed session stays as couple history (date, title, shared
--     reflection, both choices). Either partner can hide it for themselves;
--     deleting it for good needs BOTH partners to confirm (a partner who
--     leaves the couple counts as having confirmed). Titles freeze then.
--   * The app cannot write sessions or submissions directly. People act
--     through the functions below; AI results are stored only by server-only
--     functions (service_role), never by the app.
--   * Insights are saved only by their owner, and only their owner sees them.
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run.
-- Safe to run more than once.
-- =============================================================================


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
