-- =============================================================================
-- 016: Therabot guided chat: Private Talk and the Couple Reflection chat
--
-- Builds on 011. Nothing there is removed; older app versions keep working.
--
-- COUPLE REFLECTION now happens as a short guided chat instead of four fixed
-- questions. The chat is stored on the person's existing private row
-- (therabot_submissions), so it inherits every 011 rule unchanged:
--   * readable ONLY by its owner (row-level security), never by the partner;
--   * deleted with the rest of the private material at expires_at (24 hours
--     from the session's start), or sooner by "Delete my answers";
--   * written only by server-only functions (service_role).
-- Consent is recorded BEFORE the chat starts (consented_at). At the end the
-- server writes a short perspective summary and approves it for the shared
-- reflection; the shared reflection is still built only from the two
-- approved summaries (therabot_reflection_input, unchanged), never the chat.
--
-- PRIVATE TALK is a new, separate table. It is never linked to a couple
-- session, so a partner can't even tell one exists. Owner-only, 24 hours,
-- then deleted. Nothing from it can reach a shared reflection.
--
-- THE AI'S WORKING NOTES (notes) are the compact rolling context the server
-- sends instead of the whole transcript. They are not readable through the
-- API at all, not even by their owner: column privileges leave them out.
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run.
-- Safe to run more than once.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1. Couple Reflection chat, on the existing private row
-- ---------------------------------------------------------------------------

alter table public.therabot_submissions
  add column if not exists reason       text,
  add column if not exists goal         text,
  add column if not exists chat_stage   text not null default 'chat',
  add column if not exists messages     jsonb not null default '[]'::jsonb,
  add column if not exists notes        jsonb not null default '[]'::jsonb,
  add column if not exists chat_turns   smallint not null default 0,
  add column if not exists consented_at timestamptz;

do $$ begin
  alter table public.therabot_submissions
    add constraint therabot_submissions_reason_check
      check (reason is null or char_length(reason) between 1 and 120),
    add constraint therabot_submissions_goal_check
      check (goal is null or goal in ('understand', 'advice', 'explain', 'solution', 'calm', 'heard')),
    add constraint therabot_submissions_chat_stage_check
      check (chat_stage in ('open', 'chat', 'goal', 'wrap', 'done')),
    add constraint therabot_submissions_messages_check
      check (jsonb_typeof(messages) = 'array' and jsonb_array_length(messages) <= 30),
    add constraint therabot_submissions_notes_check
      check (jsonb_typeof(notes) = 'array' and jsonb_array_length(notes) <= 6),
    add constraint therabot_submissions_chat_turns_check
      check (chat_turns between 0 and 5);
exception when duplicate_object then null;
end $$;


-- ---------------------------------------------------------------------------
-- 2. Private Talk
-- ---------------------------------------------------------------------------

create table if not exists public.therabot_private_talks (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users (id) on delete cascade,
  reason           text check (reason is null or char_length(reason) between 1 and 120),
  goal             text check (goal is null
                               or goal in ('understand', 'advice', 'explain', 'solution', 'calm', 'heard')),
  stage            text not null default 'chat'
                   check (stage in ('chat', 'goal', 'wrap', 'summary', 'done', 'safety')),
  messages         jsonb not null default '[]'::jsonb
                   check (jsonb_typeof(messages) = 'array' and jsonb_array_length(messages) <= 30),
  notes            jsonb not null default '[]'::jsonb
                   check (jsonb_typeof(notes) = 'array' and jsonb_array_length(notes) <= 6),
  summary          text check (summary is null or char_length(summary) between 1 and 1500),
  ai_turns         smallint not null default 0 check (ai_turns between 0 and 5),
  summary_attempts smallint not null default 0 check (summary_attempts between 0 and 2),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  expires_at       timestamptz not null default now() + interval '24 hours',
  check (expires_at = created_at + interval '24 hours')
);

create index if not exists therabot_private_talks_user_idx
  on public.therabot_private_talks (user_id, created_at desc);
create index if not exists therabot_private_talks_expiry_idx
  on public.therabot_private_talks (expires_at);

drop trigger if exists therabot_private_talks_updated_at on public.therabot_private_talks;
create trigger therabot_private_talks_updated_at
  before update on public.therabot_private_talks
  for each row execute function public.set_updated_at();


-- ---------------------------------------------------------------------------
-- 3. Clean-up: Private Talks follow the same 24-hour rule as everything else
-- ---------------------------------------------------------------------------

-- Same as 011, plus expired Private Talks.
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
  delete from therabot_private_talks where expires_at <= now();
  return cleaned;
end;
$$;


-- ---------------------------------------------------------------------------
-- 4. What people can do themselves
-- ---------------------------------------------------------------------------

-- Saves your own edit of a Private Talk summary. Only yours, only while open.
create or replace function public.therabot_talk_save_summary(p_talk_id uuid, p_summary text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  txt text := btrim(coalesce(p_summary, ''));
begin
  if auth.uid() is null then
    raise exception 'Sign in first.';
  end if;
  if char_length(txt) not between 1 and 1500 then
    raise exception 'Your summary must be 1 to 1500 characters.';
  end if;
  update therabot_private_talks
     set summary = txt, stage = 'done'
   where id = p_talk_id and user_id = auth.uid()
     and expires_at > now() and stage in ('summary', 'done');
  if not found then
    raise exception 'This private talk is no longer open.';
  end if;
end;
$$;

-- Ends a Private Talk for now (it still clears after its 24 hours).
create or replace function public.therabot_talk_finish(p_talk_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in first.';
  end if;
  update therabot_private_talks set stage = 'done'
   where id = p_talk_id and user_id = auth.uid() and expires_at > now() and stage <> 'safety';
end;
$$;

-- Deletes your Private Talk now. Always allowed.
create or replace function public.therabot_talk_delete(p_talk_id uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in first.';
  end if;
  delete from therabot_private_talks where id = p_talk_id and user_id = auth.uid();
end;
$$;


-- ---------------------------------------------------------------------------
-- 5. Server-only functions (service_role, used by the Edge Function, which
--    has already verified the caller from their sign-in). Each re-checks
--    ownership, state, expiry and the caps itself.
-- ---------------------------------------------------------------------------

-- A new Private Talk with its opening messages. At most 5 started a day.
create or replace function public.therabot_talk_create(p_user uuid, p_reason text, p_messages jsonb)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare
  new_id uuid;
begin
  if p_user is null then
    raise exception 'Sign in first.';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('therabot_talks:' || p_user::text, 0));
  if (select count(*) from therabot_private_talks
       where user_id = p_user and created_at > now() - interval '24 hours') >= 5 then
    raise exception 'You can start up to 5 private talks a day. Try again later.';
  end if;
  insert into therabot_private_talks (user_id, reason, messages)
  values (p_user, nullif(btrim(coalesce(p_reason, '')), ''), coalesce(p_messages, '[]'::jsonb))
  returning id into new_id;
  return new_id;
end;
$$;

-- Writes a Private Talk's next state. Only against the version just read,
-- so two requests can't both add a turn; an AI turn counts toward the cap.
create or replace function public.therabot_talk_write(
  p_talk_id  uuid,
  p_user     uuid,
  p_version  timestamptz,
  p_messages jsonb,
  p_notes    jsonb,
  p_stage    text,
  p_goal     text,
  p_summary  text,
  p_ai_turn  boolean,
  p_summary_attempt boolean
)
returns timestamptz language plpgsql security definer set search_path = public, pg_temp as $$
declare
  t       therabot_private_talks;
  version timestamptz;
begin
  select * into t from therabot_private_talks
   where id = p_talk_id and user_id = p_user for update;
  if not found or t.expires_at <= now() then
    raise exception 'This private talk is no longer open.';
  end if;
  if t.stage = 'safety' then
    raise exception 'This private talk is no longer open.';
  end if;
  if p_version is null or t.updated_at is distinct from p_version then
    raise exception 'Your talk changed in the meantime. Please try again.';
  end if;

  update therabot_private_talks
     set messages         = coalesce(p_messages, messages),
         notes            = coalesce(p_notes, notes),
         stage            = coalesce(p_stage, stage),
         goal             = coalesce(p_goal, goal),
         summary          = coalesce(p_summary, summary),
         ai_turns         = ai_turns + (case when coalesce(p_ai_turn, false) then 1 else 0 end),
         summary_attempts = summary_attempts + (case when coalesce(p_summary_attempt, false) then 1 else 0 end)
   where id = t.id
  returning updated_at into version;
  return version;
end;
$$;

-- Opens YOUR part of a Couple Reflection after you consented: creates your
-- private row with the opening messages. Only for a participant of an open,
-- collecting session in their own couple, and only once.
create or replace function public.therabot_chat_open(
  p_user     uuid,
  p_session  uuid,
  p_reason   text,
  p_messages jsonb
)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare
  s      therabot_sessions;
  new_id uuid;
begin
  if p_user is null then
    raise exception 'Sign in first.';
  end if;
  select * into s from therabot_sessions where id = p_session for update;
  if not found
     or s.couple_id is distinct from (select couple_id from profiles where user_id = p_user)
     or not exists (select 1 from therabot_participants p
                     where p.session_id = s.id and p.user_id = p_user and p.left_at is null) then
    raise exception 'Therabot session not found.';
  end if;
  if s.status <> 'collecting' or s.expires_at <= now() then
    raise exception 'This Therabot session is no longer open.';
  end if;
  if exists (select 1 from therabot_submissions where session_id = s.id and user_id = p_user) then
    raise exception 'You have already started your part of this reflection.';
  end if;

  insert into therabot_submissions
         (session_id, user_id, couple_id, expires_at, reason, chat_stage, messages, consented_at)
  values (s.id, p_user, s.couple_id, s.expires_at,
          nullif(btrim(coalesce(p_reason, '')), ''),
          case when jsonb_array_length(coalesce(p_messages, '[]'::jsonb)) <= 1 then 'open' else 'chat' end,
          coalesce(p_messages, '[]'::jsonb), now())
  returning id into new_id;
  update therabot_sessions set updated_at = now() where id = s.id;
  return new_id;
end;
$$;

-- Writes your Couple Reflection chat's next state (same rules as a talk).
create or replace function public.therabot_chat_write(
  p_submission_id uuid,
  p_user          uuid,
  p_version       timestamptz,
  p_messages      jsonb,
  p_notes         jsonb,
  p_stage         text,
  p_reason        text,
  p_goal          text,
  p_ai_turn       boolean
)
returns timestamptz language plpgsql security definer set search_path = public, pg_temp as $$
declare
  sid     uuid;
  s       therabot_sessions;
  sub     therabot_submissions;
  version timestamptz;
begin
  select session_id into sid from therabot_submissions where id = p_submission_id and user_id = p_user;
  if sid is null then
    raise exception 'Submission not found.';
  end if;
  select * into s from therabot_sessions where id = sid for update;
  select * into sub from therabot_submissions where id = p_submission_id for update;
  if s.status <> 'collecting' or s.expires_at <= now() then
    raise exception 'This Therabot session is no longer open.';
  end if;
  if sub.status <> 'draft' then
    raise exception 'Your part of this reflection is already finished.';
  end if;
  if p_version is null or sub.updated_at is distinct from p_version then
    raise exception 'Your reflection changed in the meantime. Please try again.';
  end if;

  update therabot_submissions
     set messages   = coalesce(p_messages, messages),
         notes      = coalesce(p_notes, notes),
         chat_stage = coalesce(p_stage, chat_stage),
         reason     = coalesce(nullif(btrim(coalesce(p_reason, '')), ''), reason),
         goal       = coalesce(p_goal, goal),
         chat_turns = chat_turns + (case when coalesce(p_ai_turn, false) then 1 else 0 end)
   where id = sub.id
  returning updated_at into version;
  update therabot_sessions set updated_at = now() where id = s.id;
  return version;
end;
$$;

-- Finishes your part: stores the perspective summary Therabot wrote from
-- your chat AND approves it for the shared reflection (you agreed to that
-- before you started). Returns true when this was the second partner to
-- finish, so the shared reflection can be written. A safety flag closes the
-- session exactly as in 011.
create or replace function public.therabot_chat_finish(
  p_submission_id uuid,
  p_version       timestamptz,
  p_summary       jsonb,
  p_approved      text,
  p_flagged       boolean
)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare
  sid      uuid;
  s        therabot_sessions;
  sub      therabot_submissions;
  txt      text := btrim(coalesce(p_approved, ''));
  approved integer;
begin
  select session_id into sid from therabot_submissions where id = p_submission_id;
  if sid is null then
    raise exception 'Submission not found.';
  end if;
  select * into s from therabot_sessions where id = sid for update;
  select * into sub from therabot_submissions where id = p_submission_id for update;
  if s.status <> 'collecting' or s.expires_at <= now() then
    raise exception 'This Therabot session is no longer open.';
  end if;
  if sub.status <> 'draft' or sub.consented_at is null then
    raise exception 'This reflection can''t be finished now.';
  end if;
  if p_version is null or sub.updated_at is distinct from p_version then
    raise exception 'Your reflection changed in the meantime. Please try again.';
  end if;
  if p_summary is null or jsonb_typeof(p_summary) <> 'object' then
    raise exception 'Invalid summary.';
  end if;

  if coalesce(p_flagged, true) then
    update therabot_submissions
       set status = 'safety', private_summary = p_summary, approved_summary = null, chat_stage = 'done'
     where id = sub.id;
    update therabot_sessions set status = 'closed', reflection_claimed_at = null where id = s.id;
    return false;
  end if;

  if char_length(txt) not between 1 and 1500 then
    raise exception 'Invalid summary.';
  end if;
  update therabot_submissions
     set status = 'approved', private_summary = p_summary, approved_summary = txt, chat_stage = 'done'
   where id = sub.id;
  update therabot_participants set progress = 'approved'
   where session_id = s.id and user_id = sub.user_id;

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


-- ---------------------------------------------------------------------------
-- 6. Permissions and row-level security
-- ---------------------------------------------------------------------------

-- Private rows: every column except the AI's working notes. (011 granted
-- the whole table; this narrows it. Row-level security is unchanged: owner
-- only.)
revoke select on public.therabot_submissions from authenticated;
grant select (id, session_id, user_id, couple_id, expires_at,
              what_happened, feelings, wish_understood, need_now, context_used,
              private_summary, approved_summary, status, ai_attempts,
              created_at, updated_at,
              reason, goal, chat_stage, messages, chat_turns, consented_at)
  on public.therabot_submissions to authenticated;

alter table public.therabot_private_talks enable row level security;
revoke all on public.therabot_private_talks from anon, authenticated;
grant select (id, user_id, reason, goal, stage, messages, summary,
              ai_turns, summary_attempts, created_at, updated_at, expires_at)
  on public.therabot_private_talks to authenticated;

drop policy if exists "therabot talks: owner reads own open talks" on public.therabot_private_talks;
create policy "therabot talks: owner reads own open talks" on public.therabot_private_talks
  for select to authenticated
  using (user_id = auth.uid() and expires_at > now());

revoke execute on function public.therabot_talk_save_summary(uuid, text) from public, anon;
revoke execute on function public.therabot_talk_finish(uuid) from public, anon;
revoke execute on function public.therabot_talk_delete(uuid) from public, anon;
grant execute on function public.therabot_talk_save_summary(uuid, text) to authenticated;
grant execute on function public.therabot_talk_finish(uuid) to authenticated;
grant execute on function public.therabot_talk_delete(uuid) to authenticated;

revoke execute on function public.therabot_talk_create(uuid, text, jsonb) from public, anon, authenticated;
revoke execute on function public.therabot_talk_write(uuid, uuid, timestamptz, jsonb, jsonb, text, text, text, boolean, boolean)
  from public, anon, authenticated;
revoke execute on function public.therabot_chat_open(uuid, uuid, text, jsonb) from public, anon, authenticated;
revoke execute on function public.therabot_chat_write(uuid, uuid, timestamptz, jsonb, jsonb, text, text, text, boolean)
  from public, anon, authenticated;
revoke execute on function public.therabot_chat_finish(uuid, timestamptz, jsonb, text, boolean)
  from public, anon, authenticated;
revoke execute on function public.therabot_purge_expired() from public, anon, authenticated;
