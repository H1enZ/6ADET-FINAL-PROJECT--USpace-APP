# Weekly Increment Report

**Project:** USpace, a private app for two people in one relationship
**Live app:** https://h1enz.github.io/USpace/
**Commits:** https://github.com/H1enZ/USpace/commits/main

---

## Week 1: 16 to 23 September 2026

*Submitted late: the work below was done on 28 to 29 September 2026.*

### What changed this week

- **Database built.** `supabase/schema.sql` creates five tables (couples, profiles, memories, notes, bucket_items), turns on row-level security for all of them, adds the invite-code pairing functions, and a private photo bucket. I checked the policies with 33 automated attack tests (another couple reading or changing our rows, a third person joining, faking the author, opening a Time Capsule early) before running it on Supabase.
- **Theme added** from my design system: rose, plum and cream colours for light and dark mode, Poppins and Inter type scale, 4 dp spacing.
- **Shared widgets added:** AppButton, AppTextField, SectionLabel, UnlockRing, CountdownCard, AppShell (bottom bar on phones, side rail on wide screens) and SealBadge.
- **Screens built:**
  - **Splash** decides where the user goes (Sign in, Pair or Home).
  - **Sign in / Create account** in one form with two modes.
  - **Pair** lets you start a space (with an optional anniversary date) or join your partner with a 6-character code.
  - **Home** shows both names, the invite code until the partner joins, and the anniversary countdown card with its ring.
  - **Profile** shows who is signed in and has Sign out.
  - **Timeline, Love Notes and Bucket List** are placeholder tabs for now.
- **Deployed** to GitHub Pages. The Supabase URL and publishable key are passed in as repository secrets, not written in the code.
- **Tested pairing on the live app** with two accounts in two browsers. The code joined them and both names appeared on Home.
- **Splash redesigned** to match my mockup: wax seal, tagline and loading dots, shown long enough to see.
- **README rewritten** around the seven required sections, with the first screenshots.

### Why

This week was the foundation every later feature sits on. Sign-in, pairing and the privacy rules had to exist before memories, notes or the bucket list could be built, because each of those belongs to a couple. My proposal set two deadlines for 4 October: the row-level security policies tested with two accounts, and a working click-through on the web. Both are now done. The countdown card was the first real feature because it only needs the couple and a date.

### What broke or what I got stuck on

- **Wrong stack at first.** The first version was a Python/Flask app built before checking my repo. GitHub Pages only hosts static files, so it could never have been graded from the live link. I switched to Flutter + Supabase, which is what my proposal already said.
- **Files lost their folders.** The first time I copied the code in, everything ended up in one flat folder and Flutter could not find anything. Fixed by extracting the zip straight into the repo.
- **`relation "couples" already exists`** when running the SQL. The script had already run once. A check query confirmed all tables, policies, functions and the bucket were there.
- **`fatal: not a git repository`.** My terminal was in the outer folder, not the repo.
- **Untouched files showed as modified** because of Windows line endings. I restored them with `git restore` so the commits only contain real changes.
- **The live site said "This build has no Supabase settings."** The repository secrets had not been added. After adding them and re-running the workflow, the browser still showed the cached old version until I opened a private window.
- **My first screenshots showed real names and an email address,** so they cannot go in a public repo. I am retaking them with test accounts.
- **I edited two course files by mistake** (`content/finals/documentation-guide.md` and `project-README-template.md`) instead of making my own copy in `project/`. Restoring them.
- **I have not run the app locally yet.** Everything so far is tested on the deployed build only.

### What is left

- **Timeline:** add memories with a photo, caption and date, stored in the private photo bucket.
- **Bucket List**, which I will write myself.
- **Love Notes**, then **Time Capsules** with the wax seal and unlock countdown.
- **Profile:** edit name, theme switch, password reset.
- Home updating live when a partner joins, instead of pull-to-refresh.
- Finish the screenshots with test accounts.
- Install Flutter locally and follow my README's setup steps to prove they work.
- Security checklist, AI-USAGE.md entries, demo video and slides.

---

## Week 2: 23 to 27 September 2026

*Submitted late: the work below was done on 29 to 30 September 2026.*

### What changed this week

- **Timeline built:** memories with a photo, caption and date in the private photo bucket, a year filter, a detail page, and delete for the author. A database function (migration 002) lets either partner favourite a memory without being able to edit it.
- **Bucket List written by me** (model, service and screen with To do / Done / All filters, ticking and swipe to delete), then extended with a location, a budget and a shared savings log with a progress bar and the amount to save each month (migration 003). No real money moves through the app.
- **Profile built:** a profile photo in its own private bucket, editable name, and birthday with countdowns for both partners on Profile and Home (migration 004).
- **Light / Dark / System theme switch** that is remembered on the device.
- **Security checklist filled in and acted on:** GitHub Actions pinned to commit SHAs, server-side photo size and type limits (migration 005), secret scanning and push protection on, and git switched to my no-reply email.
- **Database tests grew from 33 to 61,** all passing.
- **Documentation:** Week 1 and Week 2 pages and screenshots taken with test accounts, and weekly reports for both weeks.

### Why

Week 1 gave me sign-in, pairing and Home, but the app had nothing in it yet. Memories and the Bucket List were the first features a couple would actually use together, and the Bucket List was the part I had promised to write myself, so I did it early while the schema was small. The security checklist went in the same week so the privacy rules were checked while there were few tables to check.

### What broke or what I got stuck on

- **"Could not find the table `public.bucket_contributions`"** because I pushed the code before running the migration. Running migrations 002 and 003 fixed it.
- **Profile photos failed with "Bucket not found"** because the last part of a migration had not run. A repair script that only adds what is missing fixed it.
- **My first Bucket List had five bugs,** including a Save button that could never be tapped and a text controller disposed while its dialog was still closing. A review found them and I fixed each one.
- **Pasting SQL from VS Code into the Supabase editor did not work;** copying from a browser tab did.
- **Pushes were rejected** because GitHub had newer commits. Pulling before pushing fixed it.
- **Two folders that differed only in capital letters,** which Windows treats as one, after I created one on GitHub and one on my PC. I removed the duplicate and now create files only from my PC.

### What is left

- A new Home: greeting, today's mood, a daily question, countdowns, an activity feed and quick actions.
- Love Notes and Time Capsules that stay sealed until a chosen date.
- Upgrade the Timeline into a scrapbook.
- A private realtime chat.

---

## Week 3: 28 September to 8 October 2026

### What changed this week

- **New Home** (migration 006): greeting, today's mood, a daily question, countdowns to the anniversary, birthdays and special days, an activity feed and quick actions.
- **Private realtime chat** with reactions, and **moods that share automatically** with the partner. Matching moods merge into one shared state, and notes never merge.
- **Timeline became a scrapbook:** up to 10 photos, story, location, tags, editing by both partners, then an editable, zoomable corkboard with Polaroids, tape and decorations (migrations 009, 010, 018, 019).
- **Love Notes** as paper letters with categories and an optional photo (migrations 007, 015).
- **Time Capsules** that stay sealed for both partners until a chosen date, with a wax-seal ceremony and a server-side photo function (migration 014).
- **Therabot,** a calm AI helper with Private Talk, Couple Reflection and private next steps (migrations 011, 016, 017).
- **Whole app redesigned** in ten tested batches around deep plum, cocoa, dusty rose and cream with Playfair Display and Inter: Home, Chat, Timeline (cocoa corkboard), Love Notes (paper letters), Time Capsules (parchment and candle wax), Therabot (quietest screen), Bucket List, Profile, pairing and sign-in, then shared loading, empty and error states.
- **Refactor for one couple:** a shared couple context, one live-update service (`couple_sync.dart`), preloaded fonts and icons, and the largest files split up. Tagged `v1.0-refactor-stable`.
- **Security audit** with no critical or high findings and three medium ones, then a first fix: private realtime channels (migration 021), tested on DEV against the real Realtime server.
- **Documentation updated:** live demo link at the top of the README, two tester accounts, Week 3 journal, documentation and reflection, and real AI-USAGE entries.

### Why

Week 2 left me with a working shell, so Week 3 was where USpace became the app I had in mind. I started by writing design rules (palette, fonts, motion, a personality for each screen), because the AI's output became much more consistent once it had something to check against. Once every feature existed, the risk moved from "missing" to "not trustworthy": a private app must be private, and a redesign must feel like one product. So the audit and refactor came before any new feature.

### What broke or what I got stuck on

- **A sealed Time Capsule's photo could still be changed,** and cancelling skipped the grace-period reopen. The rule moved into the database.
- **Public realtime channels** meant anyone who knew a channel name could listen. Replaced by private channels.
- **Chat scroll jumped** after a reload, and **removed reactions did not reach the partner.** Both fixed.
- **The Timeline lagged on iOS and while zooming.** I reduced the redraw work.
- **A fade-in test depended on timing** and was made deterministic.
- **The production rollout of the first security fix was stopped at step 0** to check it safely before applying anything.

### What is left

- Apply the audit fixes to the live project in stages.
- Record the demo video and finish the slides.
- Password reset.

---

## Week 4: 9 October 2026 (submission day)

### What changed this week

- **Security and privacy checklist completed**, with a `SECURITY.md` that says what is protected, where, and how to report a problem.
- **AI-USAGE.md finished:** nine "how I used AI" entries, six cases where the AI (or I) got it wrong, who wrote what (the Bucket List is my own code), every entry linked to a commit, and the placeholder notes replaced with my own explanation of `couple_sync.dart`. Commit links now use the renamed repository.
- **Repository tidied for hand-in:** copyright holder corrected in the LICENSE, the leftover `START-HERE.md` removed, optional settings documented in `.env.example`, and the example Supabase URL and key updated.
- **Demo video recorded** on 9 October against the live app with the two tester accounts. It is not in the repository yet.
- **Demo data and screenshots** from the previous night were checked: invented names and pictures only.

### Why

The features and the redesign were done, so this last stretch was about being able to prove the work: a reviewer should be able to open the repository and see what is protected, how the AI was used, and which part I wrote. The checklist and AI-USAGE.md had to be finished from the real commit history, not written from memory on the last night.

### What broke or what I got stuck on

- **The old repository name in every commit link.** The repository was renamed to `USpace`, so my links pointed at a name that only works through GitHub's redirect. I replaced them all.
- **A local branch that was one commit behind** after editing on GitHub. I used a fast-forward pull so no history was rewritten.
- **Only about 2% of the code is written by me** (the Bucket List, roughly 820 of 47,500 lines in `lib/`). The badge asks for more, and I decided to state the real figure in AI-USAGE.md instead of inflating it.

### What is left

- Add the demo video to `docs/` or link a hosted copy, and update `docs/05-demo-video.md`.
- Finish the slides.
- Apply the remaining audit fixes to the live project in stages, on my say-so.
- Password reset.
