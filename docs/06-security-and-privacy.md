# Security checklist

Project: USpace, https://github.com/H1enZ/USpace (renamed from 6ADET-FINAL-PROJECT--USpace-APP)
Live app: https://h1enz.github.io/USpace/
Completed and checked: 8 October 2026

> **Honest note on timing.** I filled this in after the repository was already public (it had to be public for GitHub Pages). I then checked the files, the full git history and my settings, and fixed what I found. Details are at the bottom.


## Secrets and credentials

| # | Check | Yes / No / N/A | Evidence |
| --- | --- | --- | --- |
| 1 | No API key, token or password is hardcoded in `lib/`, including in comments and commented-out code | Yes | I searched `lib/`, `test/` and `web/` for key patterns (`sb_publishable_`, `sb_secret_`, `eyJ`, `supabase.co`, `service_role`). The only matches were variable names like `_password`. `lib/config.dart` reads both values with `String.fromEnvironment`. |
| 2 | Anything private is in a gitignored config or passed with `--dart-define`, with an example file committed | Yes | `.env` is gitignored (`.env` and `.env.*` in `.gitignore`), and `git check-ignore .env` confirms it. `.env.example` is committed with placeholders only. Values reach the app with `--dart-define-from-file=.env` locally and `--dart-define` in the workflow. |
| 3 | No keystore, `key.properties` or signing credential is in the repository | Yes | USpace is web only: there is no `android/` or `ios/` folder, and no `*.jks`, `*.keystore` or `key.properties` file. `.gitignore` also blocks keystores. |
| 4 | Git history is clean: I searched `git log -p` for password, secret, api key and token | Yes | I searched the full history of every branch (`git log --all -p`) for `sb_secret_`, `service_role` assigned to a token, JWT-shaped `eyJ...` strings, `sk-` and `gsk_` keys, and `api_key = "..."`. Two commits matched, both titled "support new Supabase API keys in Therabot". They contain only code that checks key prefixes (`key.startsWith("sb_secret_")`) and the names of environment variables, not key values. No real key, password or token is in the history. |
| 5 | Any credential that was ever committed has been rotated | N/A | Nothing was ever committed (check 4), so there is nothing to rotate. The Therabot AI key and the service-role key are server-side Edge Function secrets, set in Supabase, and are not in the repository. |

## GitHub Actions

| # | Check | Yes / No / N/A | Evidence |
| --- | --- | --- | --- |
| 6 | No secret value is written literally in any workflow YAML file | Yes | `deploy-web.yml` only references `${{ secrets.SUPABASE_URL }}` and `${{ secrets.SUPABASE_PUBLISHABLE_KEY }}`; there are no literal values. |
| 7 | Secrets are stored in repository Actions secrets and read with `${{ secrets.NAME }}` | Yes | Both are repository secrets (Settings > Secrets and variables > Actions), read in the *Build web* step's `env:` and passed with `--dart-define`. |
| 8 | No workflow step echoes, dumps or debug-prints a secret, and I opened a recent run's log to confirm | Yes | I opened the log of the latest deploy run and searched it. `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` appear only as `***`, and the text `sb_publishable_` and any `*.supabase.co` hostname appear 0 times. The only `echo` lines in the workflow print "ready" flags and notices. |
| 9 | If I build a signed APK: the keystore is a base64 secret decoded to a file at build time, never printed | N/A | Web only; the workflow builds `flutter build web` and no APK. |
| 10 | Uploaded build artifacts contain no key file, keystore or generated config | Yes | The only artifact is `build/web` for GitHub Pages. It contains the Supabase URL and publishable key compiled into the app, which are public by design (the database rules protect the data). There is no `.env`, key file, keystore or secret key in it. |
| 11 | Third-party actions are pinned to a commit SHA, not a moveable tag | Yes | Fixed during this check: all four actions (`checkout`, `flutter-action`, `upload-pages-artifact`, `deploy-pages`) were on tags like `@v7`; they are now pinned to commit SHAs, with the tag kept as a comment. Commit: https://github.com/H1enZ/USpace/commit/0391990 |
| 12 | Secret scanning and push protection are enabled on the repository | Yes | Checked through the GitHub API on 8 October 2026: `secret_scanning` is enabled and `secret_scanning_push_protection` is enabled. |

## Backend and security rules

| # | Check | Yes / No / N/A | Evidence |
| --- | --- | --- | --- |
| 13 | Firestore and Storage rules are not left open to anyone; they require an authenticated user | Yes | Supabase, not Firestore. Both Storage buckets (`memory-photos`, `avatars`) are private, and every Storage policy is `to authenticated`. |
| 14 | Rules restrict a user to their own documents where that makes sense | Yes | Every table row is visible only to the two members of its couple; only the author can edit or delete a memory or savings entry; profile photos go only into your own folder; sealed Time Capsules and private Therabot talks are hidden from the partner by policies and column privileges. `supabase/test/rls_test.py` runs 155 attack checks against these rules and all pass; `supabase/test/realtime_private_channels.ts` tests the private realtime channels. |
| 15 | If Supabase: Row Level Security is on for every table | Yes | I compared every `create table` in `supabase/schema.sql` and `supabase/migrations/` with the `enable row level security` statements: all 25 tables have row-level security turned on. The security audit of 8 October 2026 also reported that every table has it on the live project. |
| 16 | Firebase and Google API keys are restricted in the Google Cloud console to the APIs and app they are for | N/A | No Firebase and no Google API keys. Google Fonts are loaded without a key. |
| 17 | I opened the app signed out and confirmed I could not read or write data I should not | Yes | The automated tests confirm that a signed-out visitor sees 0 rows and cannot write or call the pairing, favourite or capsule functions. The 8 October audit also checked this against the real projects: signed-out visitors (anon) got 0 rows and no writes. In the live app, signing out returns to Sign in, and the next account sees none of the previous account's data. |
| 18 | Seed and sample data is invented, not real people's data | Yes | There is no seed data file. Screenshots, the demo video and testing use two invented tester accounts (listed in the README) with made-up names, sample text and pictures drawn for this project. Screenshots that showed real names were never committed. |

## Input and app surface

| # | Check | Yes / No / N/A | Evidence |
| --- | --- | --- | --- |
| 19 | Input is validated before it is written, not only styled as valid in the UI | Yes | Checked in the app and again in the database: length limits on names, titles, captions and notes; no future memory dates or birthdays; savings and budgets must be positive. Photo size and type limits were app-only, so I added them to the Storage buckets (migration 005). |
| 20 | Nothing secret is recoverable from the built app, since a shipped binary can be unpacked | Yes | Only the Supabase URL and publishable key are in the build, and both are meant to be public. The secret (`service_role`) key is not used anywhere in the project. |

## Repository and privacy

| # | Check | Yes / No / N/A | Evidence |
| --- | --- | --- | --- |
| 21 | No student number, personal email, phone number or home address in the repository or in commit messages | No | Partly. I searched all tracked files and found no student number, phone number or home address, and no commit message contains an email or password. But every commit is authored with my personal Gmail address, so it is visible in the history. I am leaving it as it is: rewriting the history would break the commit links in AI-USAGE.md. The only other email addresses in the repository are the two invented tester accounts and made-up test addresses like `ana@x.com` in `rls_test.py`. |
| 22 | No classmate's personal data in the repository | Yes | I searched the files and the test data. The only names are me, the invented tester accounts, and made-up test users in `rls_test.py` (Ana, Ben, Cara). There are no classmates' names, numbers, faces or messages. |
| 23 | Dependencies come from pub.dev, and `build/` and `.dart_tool/` are gitignored | Yes | Every package in `pubspec.yaml` comes from pub.dev (`supabase_flutter`, `google_fonts`, `image_picker`, `shared_preferences`, `flutter_svg`, `device_preview`), and `.gitignore` lists `build/`, `.dart_tool/` and `.env`. |
| 24 | Images, fonts and other assets are mine, licensed, or credited | Yes | Fonts are Playfair Display, Inter, Lora, Caveat and La Belle Aurore (SIL Open Font License, via Google Fonts, credited in the README). The icons are USpace's own SVG line set. The 3D mood and reaction artwork is part of the app and was added by me. Mockups, screenshots and the sample pictures are my own. |
| 25 | Repository visibility is deliberate, and I checked it after my last push | Yes | The repository is public on purpose, because GitHub Pages needs it. Checked after my last push with the GitHub API: visibility is `public`, and the deploy run succeeded. |

## Anything I found and fixed

This checklist found things I did not know about:

1. **Workflow actions on moveable tags.** My actions were on tags like `@v7`, so a changed action could have run in my build. I pinned all four to commit SHAs.
2. **Photo limits only in the app.** The photo size and file-type limits only existed in the app, so someone calling the API directly could skip them. I added the same limits to both Storage buckets (migration 005).
3. **My personal email in the commit history (check 21).** Every commit is authored with my Gmail address. I decided to leave it, because rewriting the history would break the links in AI-USAGE.md, and I say so here instead.

## Security audit, 8 October 2026

After the checklist I ran a full security audit of the app and both Supabase projects (development and live). It found no critical or high problems, and separation between couples held in every test. It found three medium problems, which I am fixing in stages, development first and the live project only when I decide:

- Email confirmation is turned off on the live project. This is also why the README tells you to turn it off for test accounts.
- The realtime "something changed" channels could be joined by someone outside the couple. They carry no content, only the fact that something changed, but I am replacing them with private channels (migration 021, tested on the development project).
- Pairing codes can be guessed at scale.

I did not publish the audit reports in this repository, because they describe weaknesses of a live project. The summary above is public on purpose.
