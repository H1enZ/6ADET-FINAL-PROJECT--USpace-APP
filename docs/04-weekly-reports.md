## Week 1 (28 Sep to 4 Oct 2026)

**Done this week**
- Set up Supabase (Tokyo region) and ran `supabase/schema.sql`: five tables, row-level security on all of them, invite-code pairing functions, and a private photo bucket. The policies were checked with 33 automated attack tests before going live.
- Added the theme from my design system: colours, Poppins/Inter type scale, spacing.
- Added the first shared widgets: AppButton, AppTextField, SectionLabel, UnlockRing, CountdownCard, AppShell, SealBadge.
- Built Splash, Sign in / Create account, Pair, Home (anniversary countdown + invite code) and Profile (sign out), with placeholder tabs for Timeline, Love Notes and Bucket List.
- Deployed to GitHub Pages with the Supabase keys as repository secrets. The live link works.
- Tested pairing on the live app with two accounts in two browsers: the code joins them and both names show on Home.
- Rewrote the README around the seven required sections and added the first screenshots.

**In progress**
- Splash redesign to match my mockup (wax seal, tagline, loading dots).
- Retaking the Pair, Home, Profile, Splash and desktop screenshots with test accounts.
- Starting AI-USAGE.md entries for this week.

**Blocked or stuck on**
- My first attempt was built in Python/Flask before checking my repo. It could not run on GitHub Pages, so I switched to Flutter + Supabase.
- Extracting the files lost the folder structure, so Flutter could not find them. Fixed by extracting the zip straight into the repo.
- Running the SQL a second time gave `relation "couples" already exists`. A check query confirmed the first run had worked.
- `git` said "not a git repository" because my terminal was in the outer folder.
- Untouched files showed as modified because of line endings. I used `git restore` so they weren't committed.
- The live site showed "no Supabase settings" until I added the repository secrets and rebuilt; a private window got past the browser cache.
- My first screenshots showed real names and an email, so they cannot go in a public repo. Retaking them with test accounts.
- I have not run the app locally yet, only the deployed build.

**Decisions made, and why**
- Flutter + Supabase instead of Flask: the course deploys to GitHub Pages, which only hosts static files, and my proposal already chose Supabase.
- Privacy is enforced in the database (row-level security), not only in the app, so a bug in a screen cannot leak another couple's data.
- Couples can only be created or joined through database functions, so nobody can join a couple by editing their own profile.
- Sign in and Pair are two screens instead of one as in the mockup, because it made the flow simpler to build first.
- Screenshots and the demo use invented test accounts only.

**Hours spent, roughly:** 5 hours

**Next week I will:**
- Build Timeline: add memories with a photo, caption and date.
- Write the Bucket List screen myself.
- Run the two-couple security test on the live app and record it in docs/06-security-and-privacy.md.
- Fill in the security checklist.
- Install Flutter locally and follow my README's setup steps word for word to check they work.
