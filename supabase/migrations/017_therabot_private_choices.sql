-- =============================================================================
-- 017: Therabot next steps are chosen privately
--
-- Each partner now picks their next step (Comfort each other, Talk it
-- through, Take a breather, Reconnect gently) privately. Neither sees what
-- the other picked until BOTH have chosen; then the app compares the two
-- (same step, or a gentle bridge between two different ones).
--
--   * therabot_participants.choice is no longer readable through the API
--     (column privileges). Progress, delete requests and leaving stay
--     couple-visible as before.
--   * therabot_current() shows your partner's choice only once you have
--     both chosen; before that only WHETHER they have chosen.
--   * A choice can be changed until both have chosen; after that the
--     comparison is settled. (011 allowed changes until the 24 hours ended.)
--   * therabot_history() is unchanged: finished sessions show both choices.
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run.
-- Safe to run more than once.
-- =============================================================================

-- 1. Choices are not readable directly any more.
revoke select on public.therabot_participants from authenticated;
grant select (session_id, user_id, progress, delete_requested_at, left_at)
  on public.therabot_participants to authenticated;

-- 2. The current session, with the partner's choice held back until both chose.
drop function if exists public.therabot_current();
create function public.therabot_current()
returns table (
  session_id          uuid,
  status              text,
  i_started           boolean,
  my_partner_number   smallint,
  my_progress         text,
  partner_progress    text,
  my_choice           text,
  partner_choice      text,
  partner_has_chosen  boolean,
  title               text,
  shared_reflection   jsonb,
  created_at          timestamptz,
  expires_at          timestamptz
)
language sql stable security definer set search_path = public, pg_temp as $$
  select s.id,
         s.status,
         s.started_by is not distinct from auth.uid(),
         (case when s.started_by = auth.uid() then 1 else 2 end)::smallint,
         mine.progress,
         theirs.progress,
         mine.choice,
         case when mine.choice is not null and theirs.choice is not null then theirs.choice end,
         theirs.choice is not null,
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

-- 3. Choose (or change) your step until both of you have chosen.
create or replace function public.therabot_choose(p_session_id uuid, p_choice text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare
  s therabot_sessions;
begin
  if p_choice is null or p_choice not in ('comfort', 'talk', 'space', 'reconnect') then
    raise exception 'Choose Comfort each other, Talk it through, Take a breather or Reconnect gently.';
  end if;
  s := therabot_session_for_me(p_session_id);
  if s.status <> 'reflection_ready' or s.expires_at <= now() then
    raise exception 'Next steps can only be chosen on an open reflection.';
  end if;

  update therabot_participants set choice = p_choice
   where session_id = s.id and user_id = auth.uid();

  if not exists (select 1 from therabot_participants
                  where session_id = s.id and choice is null) then
    update therabot_sessions set status = 'completed', completed_at = now() where id = s.id;
  else
    update therabot_sessions set updated_at = now() where id = s.id;
  end if;
end;
$$;

revoke execute on function public.therabot_current() from public, anon;
grant execute on function public.therabot_current() to authenticated;
revoke execute on function public.therabot_choose(uuid, text) from public, anon;
grant execute on function public.therabot_choose(uuid, text) to authenticated;
