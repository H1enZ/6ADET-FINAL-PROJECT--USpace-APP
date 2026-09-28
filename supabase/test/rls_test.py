import uuid, psycopg2
conn = psycopg2.connect(dbname="uspace")
conn.autocommit = True
cur = conn.cursor()

results = []
def check(name, ok):
    results.append((name, ok)); print(("PASS " if ok else "FAIL ") + name)

def as_user(uid):
    cur.execute("reset role")
    cur.execute("select set_config('request.jwt.claim.sub', %s, false)", (str(uid) if uid else "",))
    cur.execute("set role authenticated")

def try_sql(sql, params=None):
    try:
        cur.execute(sql, params); return cur.fetchall() if cur.description else True
    except Exception as e:
        return e

def signup(email, name):
    cur.execute("reset role")
    uid = uuid.uuid4()
    cur.execute("insert into auth.users (id, email, raw_user_meta_data) values (%s,%s,%s)",
                (str(uid), email, '{"display_name": "%s"}' % name))
    return uid

ana, ben, cara, dan, eve = (signup(e, n) for e, n in [("ana@x.com","Ana"),("ben@x.com","Ben"),("cara@x.com","Cara"),("dan@x.com","Dan"),("eve@x.com","Eve")])

# --- trigger created profiles
as_user(ana)
check("profile auto-created with display name", try_sql("select display_name from profiles where user_id = auth.uid()") == [("Ana",)])

# --- anon can't call pairing
as_user(None); cur.execute("reset role"); cur.execute("set role anon")
check("anon cannot call create_couple", isinstance(try_sql("select create_couple(null)"), Exception))

# --- pairing
as_user(ana); code_a = try_sql("select pairing_code from create_couple('2024-02-14')")[0][0]
as_user(ben); check("partner joins with lowercase code", not isinstance(try_sql("select join_couple(%s)", (code_a.lower(),)), Exception))
as_user(eve); r = try_sql("select join_couple(%s)", (code_a,)); check("third person rejected: " + str(r).splitlines()[0], isinstance(r, Exception) and "two people" in str(r))
as_user(eve); r = try_sql("select join_couple('ZZZZZZ')"); check("wrong code rejected", isinstance(r, Exception))
as_user(ana); r = try_sql("select create_couple(null)"); check("can't create a second couple", isinstance(r, Exception) and "already" in str(r))
as_user(cara); code_c = try_sql("select pairing_code from create_couple(null)")[0][0]
as_user(dan); try_sql("select join_couple(%s)", (code_c,))
as_user(ana); couple_a = try_sql("select my_couple_id()")[0][0]
as_user(cara); couple_c = try_sql("select my_couple_id()")[0][0]

# --- profile tampering
as_user(eve); r = try_sql("update profiles set couple_id = %s where user_id = auth.uid()", (couple_a,))
check("can't join a couple by editing own profile", isinstance(r, Exception))
as_user(eve); r = try_sql("update profiles set display_name = 'Evie' where user_id = auth.uid()")
check("can rename self", not isinstance(r, Exception))
as_user(ana); try_sql("update profiles set display_name = 'Hacked' where user_id = %s", (str(cara),))
cur.execute("reset role"); cur.execute("select display_name from profiles where user_id = %s", (str(cara),))
check("can't rename someone else", cur.fetchone()[0] == "Cara")
as_user(ana); check("sees self + partner only (2 profiles)", len(try_sql("select * from profiles")) == 2)

# --- couples
as_user(ana); check("sees only own couple", try_sql("select id from couples") == [(couple_a,)])
as_user(ana); check("can't change pairing code", isinstance(try_sql("update couples set pairing_code='AAAAAA'"), Exception))
as_user(ben); check("partner can set anniversary", not isinstance(try_sql("update couples set anniversary_date = '2024-02-15'"), Exception))
as_user(ana); check("can't insert a couple directly", isinstance(try_sql("insert into couples (pairing_code) values ('BBBBBB')"), Exception))

# --- memories
as_user(ana); try_sql("insert into memories (couple_id, caption, memory_date) values (%s,'First date','2024-02-14')", (couple_a,))
as_user(ben); check("partner sees memory", len(try_sql("select * from memories")) == 1)
as_user(cara); check("other couple sees 0 memories", try_sql("select * from memories") == [])
as_user(cara); check("can't insert into another couple", isinstance(try_sql("insert into memories (couple_id, caption, memory_date) values (%s,'x','2024-01-01')", (couple_a,)), Exception))
as_user(ben); try_sql("update memories set caption='edited by ben'")
as_user(ana); check("partner can't edit author's memory", try_sql("select caption from memories") == [("First date",)])
as_user(ben); check("can't fake author_id", isinstance(try_sql("insert into memories (couple_id, author_id, caption, memory_date) values (%s,%s,'x','2024-01-01')", (couple_a, str(ana))), Exception))
as_user(ana); check("future memory date rejected", isinstance(try_sql("insert into memories (couple_id, caption, memory_date) values (%s,'x', current_date + 5)", (couple_a,)), Exception))

# --- notes / time capsule
as_user(ana); try_sql("insert into notes (couple_id, body) values (%s,'hello')", (couple_a,))
as_user(ana); try_sql("insert into notes (couple_id, body, unlock_at) values (%s,'sealed secret', now() + interval '2 minutes')", (couple_a,))
as_user(ben); rows = try_sql("select body from notes"); check("partner sees ordinary note, NOT sealed one", rows == [("hello",)])
as_user(ana); check("author also can't read own sealed note early", try_sql("select body from notes where body = 'sealed secret'") == [])
cur.execute("reset role"); cur.execute("update notes set sent_at = now() - interval '1 day', unlock_at = now() - interval '1 second' where body='sealed secret'")
as_user(ben); check("sealed note appears after unlock time", len(try_sql("select body from notes")) == 2)
as_user(cara); check("other couple sees 0 notes", try_sql("select * from notes") == [])
as_user(ben); check("partner can't edit note body", isinstance(try_sql("update notes set body='changed'"), Exception))
as_user(ben); check("partner can favourite a note", not isinstance(try_sql("update notes set is_favorite = true where body='hello'"), Exception))

# --- bucket list
as_user(ana); try_sql("insert into bucket_items (couple_id, title) values (%s,'Sunrise at Mt. Pinatubo')", (couple_a,))
as_user(ben); try_sql("update bucket_items set is_done = true")
as_user(ana); check("both partners manage bucket list", try_sql("select is_done from bucket_items") == [(True,)])
as_user(cara); check("other couple sees 0 bucket items", try_sql("select * from bucket_items") == [])

# --- storage
cur.execute("reset role")
cur.execute("insert into storage.objects (bucket_id, name) values ('memory-photos', %s)", (f"{couple_a}/beach.jpg",))
as_user(ben); check("partner can read couple's photo", len(try_sql("select name from storage.objects")) == 1)
as_user(cara); check("other couple can't see photo", try_sql("select name from storage.objects") == [])
as_user(cara); check("can't upload into another couple's folder", isinstance(try_sql("insert into storage.objects (bucket_id, name) values ('memory-photos', %s)", (f"{couple_a}/x.jpg",)), Exception))
as_user(cara); check("can upload into own folder", not isinstance(try_sql("insert into storage.objects (bucket_id, name) values ('memory-photos', %s)", (f"{couple_c}/y.jpg",)), Exception))

# --- signed out
as_user(None); cur.execute("reset role"); cur.execute("set role anon")
check("signed-out visitor sees 0 memories", try_sql("select * from memories") == [])

# --- favourites (migration 002)
as_user(ana); mem = try_sql("insert into memories (couple_id, caption, memory_date) values (%s,'Fav me','2024-05-01') returning id", (couple_a,))[0][0]
as_user(ben); check("partner can favourite author's memory", try_sql("select toggle_memory_favorite(%s)", (mem,)) == [(True,)])
as_user(ana); check("favourite is shared by both", try_sql("select is_favorite from memories where id = %s", (mem,)) == [(True,)])
as_user(ben); check("partner still can't edit the caption", (try_sql("update memories set caption='x' where id = %s", (mem,)) is True) and try_sql("select caption from memories where id = %s", (mem,)) == [("Fav me",)])
as_user(cara); check("other couple can't favourite it", isinstance(try_sql("select toggle_memory_favorite(%s)", (mem,)), Exception))
cur.execute("reset role"); cur.execute("set role anon")
check("signed-out visitor can't call it", isinstance(try_sql("select toggle_memory_favorite(%s)", (mem,)), Exception))

# --- bucket details and savings (migration 003)
as_user(ana); trip = try_sql("insert into bucket_items (couple_id, title, location_area, location_spot, budget) values (%s, 'See the bamboo forest', 'Kyoto, Japan', 'Arashiyama Bamboo Grove', 60000) returning id", (couple_a,))[0][0]
check("item keeps location and budget", try_sql("select location_area, location_spot, budget from bucket_items where id = %s", (trip,)) == [("Kyoto, Japan", "Arashiyama Bamboo Grove", 60000)])
check("budget must be positive", isinstance(try_sql("insert into bucket_items (couple_id, title, budget) values (%s, 'x', -5)", (couple_a,)), Exception))
as_user(ana); check("can log savings for own item", not isinstance(try_sql("insert into bucket_contributions (item_id, couple_id, amount, note) values (%s, %s, 500, 'allowance')", (trip, couple_a)), Exception))
as_user(ben); check("partner can log savings too", not isinstance(try_sql("insert into bucket_contributions (item_id, couple_id, amount) values (%s, %s, 1500)", (trip, couple_a)), Exception))
as_user(ana); check("both entries add up", try_sql("select sum(amount) from bucket_contributions where item_id = %s", (trip,)) == [(2000,)])
as_user(ana); check("amount must be positive", isinstance(try_sql("insert into bucket_contributions (item_id, couple_id, amount) values (%s, %s, 0)", (trip, couple_a)), Exception))
as_user(ben); check("can't log savings as partner", isinstance(try_sql("insert into bucket_contributions (item_id, couple_id, author_id, amount) values (%s, %s, %s, 10)", (trip, couple_a, str(ana))), Exception))
as_user(cara); check("other couple sees no savings", try_sql("select * from bucket_contributions") == [])
as_user(cara); check("other couple can't log to our item", isinstance(try_sql("insert into bucket_contributions (item_id, couple_id, amount) values (%s, %s, 10)", (trip, couple_c)), Exception))
as_user(ben); try_sql("delete from bucket_contributions where note = 'allowance'")
as_user(ana); check("partner can't delete my entry", try_sql("select count(*) from bucket_contributions where note = 'allowance'") == [(1,)])
as_user(ana); check("entries can't be edited", isinstance(try_sql("update bucket_contributions set amount = 99999"), Exception))
as_user(ana); try_sql("delete from bucket_items where id = %s", (trip,))
cur.execute("reset role"); cur.execute("select count(*) from bucket_contributions where item_id = %s", (trip,))
check("deleting the item deletes its savings log", cur.fetchone()[0] == 0)

print(f"\n{sum(ok for _, ok in results)}/{len(results)} passed")
