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

# --- profile birthday and photo (migration 004)
as_user(ana); check("can set own birthday", not isinstance(try_sql("update profiles set birthday = '2003-02-14' where user_id = auth.uid()"), Exception))
as_user(ben); check("partner can see my birthday", try_sql("select birthday::text from profiles where user_id = %s", (str(ana),)) == [("2003-02-14",)])
as_user(cara); check("other couple can't see my birthday", try_sql("select birthday from profiles where user_id = %s", (str(ana),)) == [])
as_user(ben); try_sql("update profiles set birthday = '1999-01-01' where user_id = %s", (str(ana),))
as_user(ana); check("partner can't change my birthday", try_sql("select birthday::text from profiles where user_id = auth.uid()") == [("2003-02-14",)])
as_user(ana); check("future birthday rejected", isinstance(try_sql("update profiles set birthday = current_date + 30 where user_id = auth.uid()"), Exception))
as_user(ana); check("can upload own photo", not isinstance(try_sql("insert into storage.objects (bucket_id, name) values ('avatars', %s)", (f"{ana}/me.jpg",)), Exception))
as_user(ben); check("can't upload into partner's photo folder", isinstance(try_sql("insert into storage.objects (bucket_id, name) values ('avatars', %s)", (f"{ana}/fake.jpg",)), Exception))
as_user(ben); check("partner can see my photo", len(try_sql("select name from storage.objects where bucket_id = 'avatars' and name like %s", (f"{ana}/%",))) == 1)
as_user(cara); check("other couple can't see my photo", try_sql("select name from storage.objects where bucket_id = 'avatars'") == [])
as_user(ben); try_sql("delete from storage.objects where bucket_id = 'avatars' and name = %s", (f"{ana}/me.jpg",))
cur.execute("reset role"); cur.execute("select count(*) from storage.objects where name = %s", (f"{ana}/me.jpg",))
check("partner can't delete my photo", cur.fetchone()[0] == 1)
as_user(ana); try_sql("delete from storage.objects where bucket_id = 'avatars' and name = %s", (f"{ana}/me.jpg",))
cur.execute("reset role"); cur.execute("select count(*) from storage.objects where name = %s", (f"{ana}/me.jpg",))
check("I can delete my own photo", cur.fetchone()[0] == 0)

# =================== Week 3 (migration 006) ===================
def one(sql, params=None):
    r = try_sql(sql, params)
    return r[0][0] if isinstance(r, list) and r else r

# --- richer memories
as_user(ana); m3 = one("insert into memories (couple_id, caption, memory_date) values (%s,'Beach day','2025-07-01') returning id", (couple_a,))
check("author can add description, location and tags", not isinstance(try_sql("update memories set description='Sunset swim', location='Zambales', tags=array['travel','special'] where id=%s", (m3,)), Exception))
check("unknown tag rejected", isinstance(try_sql("update memories set tags=array['party'] where id=%s", (m3,)), Exception))
as_user(ben); try_sql("update memories set description='hacked' where id=%s", (m3,))
as_user(ana); check("partner can't edit my memory's story", one("select description from memories where id=%s", (m3,)) == "Sunset swim")

# --- memory photos
as_user(ana); check("author adds photos to own memory", not isinstance(try_sql("insert into memory_photos (memory_id, couple_id, path, position) values (%s,%s,%s,0)", (m3, couple_a, f"{couple_a}/m3-0.jpg")), Exception))
check("photo path must be in own couple folder", isinstance(try_sql("insert into memory_photos (memory_id, couple_id, path, position) values (%s,%s,%s,1)", (m3, couple_a, f"{couple_c}/x.jpg")), Exception))
check("max 10 photos (position 0-9)", isinstance(try_sql("insert into memory_photos (memory_id, couple_id, path, position) values (%s,%s,%s,10)", (m3, couple_a, f"{couple_a}/m3-10.jpg")), Exception))
as_user(ben); check("partner can't add photos to my memory", isinstance(try_sql("insert into memory_photos (memory_id, couple_id, path, position) values (%s,%s,%s,2)", (m3, couple_a, f"{couple_a}/m3-2.jpg")), Exception))
check("partner sees the photos", len(try_sql("select * from memory_photos where memory_id=%s", (m3,))) == 1)
as_user(cara); check("other couple sees no memory photos", try_sql("select * from memory_photos") == [])

# --- chat
as_user(ana); msg1 = one("insert into messages (couple_id, body) values (%s,'Good morning ❤️') returning id", (couple_a,))
check("can send a message", msg1 is not None and not isinstance(msg1, Exception))
as_user(ben); check("partner receives it", one("select body from messages where id=%s", (msg1,)) == "Good morning ❤️")
as_user(cara); check("other couple can't read our chat", try_sql("select * from messages") == [])
as_user(ben); check("can't send as my partner", isinstance(try_sql("insert into messages (couple_id, sender_id, body) values (%s,%s,'fake')", (couple_a, str(ana))), Exception))
as_user(cara); check("can't post into another couple's chat", isinstance(try_sql("insert into messages (couple_id, body) values (%s,'hi')", (couple_a,)), Exception))
as_user(ana); check("new message can't arrive already read", isinstance(try_sql("insert into messages (couple_id, body, read_at) values (%s,'x', now())", (couple_a,)), Exception))
check("empty message rejected", isinstance(try_sql("insert into messages (couple_id) values (%s)", (couple_a,)), Exception))
old = one("insert into messages (couple_id, body, created_at) values (%s,'back-dated','2000-01-01') returning created_at::date > current_date - 1", (couple_a,))
check("messages can't be back-dated", old is True)
check("chat photo must be in own couple folder", isinstance(try_sql("insert into messages (couple_id, photo_path) values (%s,%s)", (couple_a, f"{couple_c}/chat/x.jpg")), Exception))
as_user(ben); check("messages can't be changed directly", isinstance(try_sql("update messages set body='changed' where id=%s", (msg1,)), Exception))
check("can't edit partner's message", isinstance(try_sql("select edit_message(%s, 'changed')", (msg1,)), Exception))
as_user(ana); try_sql("select edit_message(%s, 'Good morning, love ❤️')", (msg1,))
check("can edit my own message, marked edited", try_sql("select body, edited_at is not null from messages where id=%s", (msg1,)) == [("Good morning, love ❤️", True)])
as_user(ben); check("can't delete partner's message", isinstance(try_sql("select delete_message(%s)", (msg1,)), Exception))
as_user(ana); pmsg = one("insert into messages (couple_id, body, photo_path) values (%s,'pic',%s) returning id", (couple_a, f"{couple_a}/chat/p.jpg"))
check("deleting returns the photo to remove", one("select delete_message(%s)", (pmsg,)) == f"{couple_a}/chat/p.jpg")
check("deleted message keeps no text or photo", try_sql("select body, photo_path, deleted_at is not null from messages where id=%s", (pmsg,)) == [(None, None, True)])
as_user(ben); try_sql("select mark_messages_read()")
as_user(ana); check("partner reading marks my message read", one("select read_at is not null from messages where id=%s", (msg1,)) is True)
mine = one("insert into messages (couple_id, body) values (%s,'unread') returning id", (couple_a,))
try_sql("select mark_messages_read()")
check("I can't mark my own sent messages read", one("select read_at is null from messages where id=%s", (mine,)) is True)
as_user(cara); try_sql("select mark_messages_read()")
as_user(ana); check("other couple can't mark our messages read", one("select read_at is null from messages where id=%s", (mine,)) is True)

# --- reactions
as_user(ben); check("partner can react", not isinstance(try_sql("insert into message_reactions (message_id, couple_id, emoji) values (%s,%s,'❤️')", (msg1, couple_a)), Exception))
try_sql("update message_reactions set emoji='😂' where message_id=%s", (msg1,))
check("can change my reaction", one("select emoji from message_reactions where message_id=%s", (msg1,)) == "😂")
check("only the allowed emojis", isinstance(try_sql("insert into message_reactions (message_id, couple_id, emoji) values (%s,%s,'💩')", (mine, couple_a)), Exception))
check("can't react as my partner", isinstance(try_sql("insert into message_reactions (message_id, couple_id, user_id, emoji) values (%s,%s,%s,'❤️')", (mine, couple_a, str(ana))), Exception))
as_user(cara); check("other couple can't react to our messages", isinstance(try_sql("insert into message_reactions (message_id, couple_id, emoji) values (%s,%s,'❤️')", (msg1, couple_c)), Exception))
check("other couple sees no reactions", try_sql("select * from message_reactions") == [])
as_user(ana); try_sql("delete from message_reactions where message_id=%s", (msg1,))
as_user(ben); check("can't remove partner's reaction", len(try_sql("select * from message_reactions where message_id=%s", (msg1,))) == 1)

# --- moods
as_user(ana); try_sql("insert into moods (couple_id, mood, note) values (%s,'happy','exam passed')", (couple_a,))
try_sql("insert into moods (couple_id, mood, note, is_shared) values (%s,'sad','private thing',false)", (couple_a,))
as_user(ben); check("partner sees my shared mood", [r[0] for r in try_sql("select mood from moods where user_id=%s", (str(ana),))] == ["happy"])
as_user(ana); check("I see my private mood too", len(try_sql("select * from moods where user_id=auth.uid()")) == 2)
as_user(cara); check("other couple sees no moods", try_sql("select * from moods") == [])
as_user(ana); check("unknown mood rejected", isinstance(try_sql("insert into moods (couple_id, mood) values (%s,'hangry')", (couple_a,)), Exception))
as_user(ben); check("can't check in as my partner", isinstance(try_sql("insert into moods (couple_id, user_id, mood) values (%s,%s,'happy')", (couple_a, str(ana))), Exception))

# --- daily question
q = "What made you smile today?"
as_user(ben); try_sql("insert into question_answers (couple_id, question_date, question, answer) values (%s, current_date, %s, 'Your good-morning text')", (couple_a, q))
as_user(ana); check("partner's answer hidden until I answer", try_sql("select answer from question_answers where user_id=%s", (str(ben),)) == [])
try_sql("insert into question_answers (couple_id, question_date, question, answer) values (%s, current_date, %s, 'Passing my exam')", (couple_a, q))
check("partner's answer visible after I answer", one("select answer from question_answers where user_id=%s", (str(ben),)) == "Your good-morning text")
check("one answer per person per day", isinstance(try_sql("insert into question_answers (couple_id, question_date, question, answer) values (%s, current_date, %s, 'again')", (couple_a, q)), Exception))
check("can edit my answer", not isinstance(try_sql("update question_answers set answer='Passing my exam (and you)' where user_id=auth.uid()"), Exception))
as_user(ben); try_sql("update question_answers set answer='hacked' where user_id=%s", (str(ana),))
as_user(ana); check("partner can't edit my answer", one("select answer from question_answers where user_id=auth.uid()") == "Passing my exam (and you)")
as_user(cara); check("other couple sees no answers", try_sql("select * from question_answers") == [])

# --- important dates
as_user(ana); d1 = one("insert into important_dates (couple_id, title, event_date) values (%s,'First date','2023-06-19') returning id", (couple_a,))
as_user(ben); try_sql("update important_dates set title='Our first date' where id=%s", (d1,))
check("both partners can edit important dates", one("select title from important_dates where id=%s", (d1,)) == "Our first date")
as_user(cara); check("other couple sees no dates", try_sql("select * from important_dates") == [])

# --- affection
as_user(ana); hug = one("insert into affections (couple_id, kind, message) values (%s,'hug','Big warm hug') returning id", (couple_a,))
as_user(ben); check("partner receives the hug", one("select kind from affections where id=%s", (hug,)) == "hug")
as_user(ana); check("can't send already seen", isinstance(try_sql("insert into affections (couple_id, kind, seen_at) values (%s,'kiss', now())", (couple_a,)), Exception))
check("unknown affection rejected", isinstance(try_sql("insert into affections (couple_id, kind) values (%s,'slap')", (couple_a,)), Exception))
try_sql("select mark_affections_seen()")
check("I can't mark my own hug seen", one("select seen_at is null from affections where id=%s", (hug,)) is True)
as_user(ben); try_sql("select mark_affections_seen()")
check("receiver marks it seen", one("select seen_at is not null from affections where id=%s", (hug,)) is True)
check("affections can't be changed directly", isinstance(try_sql("update affections set message='x' where id=%s", (hug,)), Exception))
as_user(cara); check("other couple sees no affection", try_sql("select * from affections") == [])

# --- resolution notes
as_user(ana); try_sql("insert into resolution_notes (couple_id, need, what_happened, is_shared) values (%s,'listen','my private draft',false)", (couple_a,))
shared_note = one("insert into resolution_notes (couple_id, need, what_happened) values (%s,'solution','we disagreed about plans') returning id", (couple_a,))
as_user(ben); check("partner sees only my shared note", [r[0] for r in try_sql("select what_happened from resolution_notes where author_id=%s", (str(ana),))] == ["we disagreed about plans"])
try_sql("update resolution_notes set what_happened='hacked' where id=%s", (shared_note,))
as_user(ana); check("partner can't edit my note", one("select what_happened from resolution_notes where id=%s", (shared_note,)) == "we disagreed about plans")
as_user(cara); check("other couple sees no notes", try_sql("select * from resolution_notes") == [])

# --- activity feed
as_user(ana); kinds = {r[0] for r in try_sql("select kind from activities")}
check("feed logs memories, moods, answers, dates, affection", {"memory_added", "mood_updated", "question_answered", "date_added", "affection_sent"} <= kinds)
check("private mood is not in the feed", one("select count(*) from activities where kind='mood_updated'") == 1)
check("feed never contains mood notes", one("select count(*) from activities where detail ilike '%exam%' or detail ilike '%private%'") == 0)
check("app can't write fake activity", isinstance(try_sql("insert into activities (couple_id, actor_id, kind) values (%s,%s,'memory_added')", (couple_a, str(ana))), Exception))
as_user(cara); check("other couple sees no activity", try_sql("select * from activities where couple_id=%s", (couple_a,)) == [])
as_user(None); cur.execute("reset role"); cur.execute("set role anon")
check("signed-out visitor sees no chat", try_sql("select * from messages") == [] or isinstance(try_sql("select * from messages"), Exception))
cur.execute("reset role"); cur.execute("select count(*) from pg_publication_tables where pubname='supabase_realtime' and tablename in ('messages','message_reactions','affections','activities')")
check("chat, reactions, affection and feed are realtime", cur.fetchone()[0] == 4)

# =================== Love notes & time capsules (migration 007) ===================
as_user(ana)
check("sealed capsule can't be read back even with RETURNING", isinstance(try_sql("insert into notes (couple_id, body, unlock_at) values (%s,'x', now() + interval '1 day') returning id", (couple_a,)), Exception))
r = try_sql("insert into notes (couple_id, body, unlock_at, capsule_title) values (%s,'Happy anniversary, love', now() + interval '30 days','Open on our anniversary')", (couple_a,))
check("can seal a time capsule with a teaser", not isinstance(r, Exception))
cap = one("select id from sealed_notes() where capsule_title = 'Open on our anniversary'")
as_user(ben)
env = try_sql("select author_id::text, capsule_title from sealed_notes()")
check("partner sees the sealed envelope", (str(ana), "Open on our anniversary") in env)
check("sealed_notes never returns the message", "body" not in [d[0] for d in cur.description] if cur.description else True)
check("partner still can't read the sealed text", try_sql("select body from notes where id=%s", (cap,)) == [])
as_user(ana); check("author can't read own sealed text early either", try_sql("select body from notes where id=%s", (cap,)) == [])
check("author sees own envelope too", len([r for r in try_sql("select id from sealed_notes()") if str(r[0]) == str(cap)]) == 1)
as_user(cara); check("other couple sees no envelopes", try_sql("select * from sealed_notes()") == [])
check("teaser max 60 characters", isinstance(try_sql("insert into notes (couple_id, body, unlock_at, capsule_title) values (%s,'x', now() + interval '1 day', %s)", (couple_c, "x" * 61)), Exception))
as_user(ben); check("partner can't cancel my capsule", isinstance(try_sql("select cancel_capsule(%s)", (cap,)), Exception))
as_user(ana); try_sql("select cancel_capsule(%s)", (cap,))
check("author can cancel own sealed capsule", not any(str(r[0]) == str(cap) for r in try_sql("select id from sealed_notes()")))
opened = one("insert into notes (couple_id, body) values (%s,'An open note') returning id", (couple_a,))
check("can't cancel a note that isn't sealed", isinstance(try_sql("select cancel_capsule(%s)", (opened,)), Exception))
try_sql("insert into notes (couple_id, body, unlock_at, capsule_title) values (%s,'future me', now() + interval '1 day', 'Tomorrow')", (couple_a,))
cap2 = one("select id from sealed_notes() where capsule_title = 'Tomorrow'")
check("feed says a capsule was sealed", one("select count(*) from activities where kind='note_sent' and detail='capsule'") >= 1)
cur.execute("reset role"); cur.execute("set role anon")
check("signed-out visitor can't list envelopes", isinstance(try_sql("select * from sealed_notes()"), Exception))
cur.execute("reset role"); cur.execute("update notes set sent_at = now() - interval '2 days', unlock_at = now() - interval '1 minute' where id = %s", (cap2,))
as_user(ben); check("capsule opens for partner at unlock time", one("select body from notes where id=%s", (cap2,)) == "future me")
check("opened capsule leaves the envelope list", not any(str(r[0]) == str(cap2) for r in try_sql("select id from sealed_notes()")))
cur.execute("reset role"); cur.execute("select count(*) from pg_publication_tables where pubname='supabase_realtime' and tablename='notes'")
check("new notes are realtime", cur.fetchone()[0] == 1)

print(f"\n{sum(ok for _, ok in results)}/{len(results)} passed")
