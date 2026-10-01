-- =============================================================================
-- 008: unlink from your partner (leave the couple)
--
-- leave_couple():
--   * removes you from your couple, so you no longer see any of its data
--   * if your partner is still in it, they keep everything (including what
--     you created) and the couple gets a NEW invite code, so you cannot get
--     back in with the old one unless your partner sends you the new code
--   * if nobody is left, the couple and everything in it is deleted, since
--     no one could ever reach it again
--
-- HOW TO USE: Supabase > SQL Editor > New query > paste this file > Run.
-- Safe to run more than once.
-- =============================================================================

create or replace function public.leave_couple()
returns void
language plpgsql
security definer
set search_path = public
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
