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
