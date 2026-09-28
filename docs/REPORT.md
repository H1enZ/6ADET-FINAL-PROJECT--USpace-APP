# Weekly Increment Report

**Project:** USpace, a private app for two people in one relationship
**Live app:** https://h1enz.github.io/6ADET-FINAL-PROJECT--USpace-APP/
**Commits:** https://github.com/H1enZ/6ADET-FINAL-PROJECT--USpace-APP/commits/main

---

## Week of: 28 September to 4 October 2026 (Week 1)

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
