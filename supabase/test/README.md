# Security policy test

`rls_test.py` runs 38 attack checks against `../schema.sql` with two couples
and a fifth person: reading or changing the other couple's rows and photos,
joining a full couple, faking an author, editing a profile to join a couple,
opening a sealed Time Capsule early, and favouriting (either partner can, outsiders cannot, and the partner still cannot edit the caption).

It needs a local PostgreSQL. `supabase_mock.sql` stands in for the parts
Supabase normally provides (`auth.users`, `auth.uid()`, the storage schema,
and the `anon` / `authenticated` roles).

```bash
createdb uspace
psql -d uspace -f supabase/test/supabase_mock.sql
psql -d uspace -f supabase/schema.sql
pip install psycopg2-binary
python supabase/test/rls_test.py
```

This checks the policy logic. It does not replace testing the real thing:
two accounts in two different couples on the live Supabase project.
