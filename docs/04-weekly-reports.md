# Weekly reports

## Week 1 (September 16, 2026 to September 23, 2026)

*Submitted late: the work below was done on 28 to 29 September 2026.*

**Done this week**
- Switched the project to Flutter + Supabase to match my proposal, after a first version in Python/Flask turned out not to fit the course (GitHub Pages cannot run a Python server).
- Created the Supabase database with `supabase/schema.sql`: five tables, row-level security on every table, invite-code pairing functions and a private photo bucket, checked with 33 automated security tests before running it.
- Built the Material 3 theme from my design system: rose, plum and cream colours for Light and Dark, the Poppins and Inter type scale, and 4 dp spacing.
- Added the first shared widgets: AppButton, AppTextField, SectionLabel, UnlockRing, CountdownCard, AppShell and SealBadge.
- Built Splash, Sign in / Create account, Pair, Home (names, invite code and anniversary countdown) and Profile (sign out), with placeholder tabs for Timeline, Love Notes and Bucket List.
- Redesigned the splash to match my mockup (wax seal, tagline, loading dots), made it wait for a tap before Sign in, and centred it.
- Deployed to GitHub Pages with the Supabase URL and publishable key as repository secrets, and tested pairing with two accounts in two browsers.
- Rewrote the README around the seven required documentation sections.

**In progress**
- Timeline, Love Notes and Bucket List screens.
- Screenshots of every screen using test accounts.
- AI-USAGE.md entries.

**Blocked or stuck on**
- Copying the code in flattened every file into one folder, so Flutter could not find them. Fixed by extracting the zip straight into the repository.
- `fatal: not a git repository`: my terminal was in the outer folder instead of the repo.
- Files I never touched showed as modified because of Windows line endings. I restored them with `git restore` so they were not committed.
- Running the SQL a second time gave `relation "couples" already exists`; a check query confirmed the first run had worked.
- The live site showed "This build has no Supabase settings" until I added the repository secrets and cleared the browser's cached copy.
- My first screenshots showed real names and an email address, so they could not go in a public repository and had to be retaken.

**Decisions made, and why**
- **Flutter + Supabase instead of Flask:** the course deploys to GitHub Pages, which only hosts static files, and my proposal already chose Supabase.
- **Privacy in the database:** row-level security decides who can read each row, so a bug in a screen cannot leak another couple's data.
- **Pairing only through database functions:** nobody can join a couple by editing their own profile.
- **Sign in and Pair as two screens:** simpler to build first, even though the mockup shows them as one.
- **Test accounts only in screenshots:** the repository is public.

**Hours spent, roughly:**
- 6

**Next week I will:**
- Build the Timeline with photos, and the Bucket List.
- Build the Profile: photo, name and birthday.
- Add a Light / Dark / System theme switch.
- Fill in the security checklist.

---

## Week 2 (September 23, 2026 to September 27, 2026)

*Submitted late: the work below was done on 29 to 30 September 2026.*

**Done this week**
- Built the Timeline: memories with a photo, caption and date in the private photo bucket, a year filter, a memory detail page, and delete for the author. Added a database function so either partner can favourite a memory, without being able to edit it.
- Wrote the first version of the Bucket List myself (model, service, screen with To do / Done / All filters, ticking and swipe to delete).
- Extended the Bucket List with a location (country or state plus a specific spot), a budget and a shared savings log, with a progress bar and the amount to save each month. No real money moves through the app.
- Built the Profile: profile photo in its own private bucket, editable name, and birthday with countdowns for both partners on Profile and Home.
- Added a Light / Dark / System theme switch that is remembered on the device.
- Filled in the security checklist and fixed what it found: pinned the GitHub Actions to commit SHAs, added server-side photo size and type limits, turned on secret scanning and push protection, and switched git to my GitHub no-reply email.
- Grew the database security tests from 33 to 61, all passing.
- Added the Week 1 and Week 2 documentation pages and screenshots taken with test accounts.

**In progress**
- Week 3: the new Home page, Love Notes and Time Capsules, and the upgraded Timeline.
- Writing section 3 of AI-USAGE.md ("who wrote what") in my own words.

**Blocked or stuck on**
- The Bucket List showed "Could not find the table 'public.bucket_contributions'" because I pushed the code before running the database migration. Running migrations 002 and 003 fixed it.
- Profile photos failed with "Bucket not found": the last part of a migration had not run. A repair script that only adds what is missing fixed it.
- Pasting SQL into the Supabase editor did not work from VS Code; opening the file in a browser tab and copying from there did.
- My first Bucket List version had five bugs, including a Save button that could never be tapped and a text controller disposed while the dialog was still closing. They were found in review and fixed.
- Pushes were rejected several times because GitHub had newer commits; `git pull --rebase` before pushing fixed it.
- Creating a folder on the GitHub website and another on my PC gave two folders whose names differed only in capital letters, which Windows treats as one. I removed the duplicate and now create files only from my PC.

**Decisions made, and why**
- **Savings are a record, not real money:** holding or moving money would need a licensed payment provider, so the app tracks savings kept in the couple's own bank or e-wallet account.
- **Profile photos in their own private bucket:** each person can only upload to their own folder, and only the couple can see the photos.
- **The theme choice stays on the device:** it is a personal preference, not the couple's shared data.
- **Old commits keep my Gmail:** rewriting the history would break the commit links in AI-USAGE.md, so I changed the email for new commits instead and wrote this down honestly in the checklist.

**Hours spent, roughly:**
- 6

**Next week I will:**
- Redesign Home: greeting, today's mood, a daily question, countdowns to special dates, a recent activity feed and quick actions.
- Build Love Notes with Time Capsules that stay sealed for both partners until a chosen date.
- Upgrade the Timeline into a scrapbook with multiple photos, a story, location, tags, filters and editing.
- Build a private realtime chat.

---

## Week 3 (September 28, 2026 to October 8, 2026)

**Done this week**
- Redesigned Home: greeting, today's mood, a daily question, countdowns to anniversary, birthdays and special days, an activity feed and quick actions (migration 006).
- Built a private realtime chat with reactions, and moods that share automatically with the partner (matching moods merge into one shared state; notes never merge).
- Upgraded the Timeline into a scrapbook: up to 10 photos, story, location, tags, editing by both partners, then an editable, zoomable corkboard with Polaroids, tape and decorations (migrations 009, 010, 018, 019).
- Built Love Notes as paper letters with categories and an optional photo (migrations 007, 015).
- Built Time Capsules that stay sealed for both partners until a chosen date, with a wax-seal ceremony and a server-side photo function (migration 014).
- Built Therabot, a calm AI helper with Private Talk and Couple Reflection and private next steps (migrations 011, 016, 017).
- Redesigned the whole app in ten tested batches around a deep plum, cocoa, dusty rose and cream palette with Playfair Display and Inter, plus shared loading, empty and error states.
- Refactored: one shared couple context and one live-update service, faster font and icon loading, the largest files split up. Tagged `v1.0-refactor-stable`.
- Ran a security audit (no critical or high findings, three medium) and started fixing it in stages: private realtime channels (migration 021, tested on DEV).
- Added two tester accounts and the live demo link at the top of the README, and wrote the Week 3 journal, documentation, reflection and AI-USAGE entries.

**In progress**
- Applying the security fixes to the live project, DEV first.
- Retaking screenshots with the tester accounts.
- Demo video.

**Blocked or stuck on**
- A sealed Time Capsule's photo could still be changed, and cancelling skipped the grace-period reopen. Fixed in the database.
- Realtime channels were public, so anyone who knew a name could join. Replaced with private channels that only the two partners can join.
- Scroll jumping in chat after a reload, and a reaction removal that did not reach the partner. Both fixed.
- The timeline lagged on iOS and while zooming. Reduced the redraw work.

**Decisions made, and why**
- **Design rules written down first:** a palette, fonts, motion rules and a screen personality for each tab, so every later change had something to be checked against.
- **Mood sharing is automatic:** no "Share mood" button, and notes never merge, so a match never hides what someone wrote.
- **Security in the database:** sealed capsules and private Therabot talks are enforced by row-level security and Edge Functions, not the screens.
- **Audit before more features:** the last days went to cleanup, realtime and security, not new screens.
- **Production only on request:** schema and security changes go to DEV first and to the live project only when I say so.

**Hours spent, roughly:**
- 40

**Next week I will:**
- Finish the security fixes and apply them to the live project.
- Retake all screenshots with the tester accounts.
- Record the demo video.
- Make sure I can explain every part of the project.

---

## Week N (date to date)

**Done this week**
-

**In progress**
-

**Blocked or stuck on**
-

**Decisions made, and why**
-

**Hours spent, roughly:**

**Next week I will:**
-
