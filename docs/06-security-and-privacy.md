# Security checklist

Project: USpace, https://github.com/H1enZ/6ADET-FINAL-PROJECT--USpace-APP

> **Honest note on timing.** I filled this in after the repository was already public (it had to be public for GitHub Pages). I then checked the files, the full git history and my settings, and fixed what I found. Details are at the bottom.

<!-- Before submitting: replace every TO CHECK with Yes / No / N/A and your evidence, then reword every evidence line in your own words and delete this comment. -->

## Secrets and credentials

| # | Check | Yes / No / N/A | Evidence |
| --- | --- | --- | --- |
| 1 | No API key, token or password is hardcoded in `lib/`, including in comments and commented-out code | Yes | I searched `lib/`, `test/` and `web/` for key patterns (`sb_publishable_`, `sb_secret_`, `eyJ`, `supabase.co`, `service_role`). The only matches were variable names like `_password`. `lib/config.dart` reads both values with `String.fromEnvironment`. |
| 2 | Anything private is in a gitignored config or passed with `--dart-define`, with an example file committed | Yes | `.env` is gitignored (`.env` and `.env.*` in `.gitignore`), and `git check-ignore .env` confirms it. `.env.example` is committed with placeholders only. Values reach the app with `--dart-define-from-file=.env` locally and `--dart-define` in the workflow. |
| 3 | No keystore, `key.properties` or signing credential is in the repository | Yes | USpace is web only: there is no `android/` or `ios/` folder, and no `*.jks`, `*.keystore` or `key.properties` file. `.gitignore` also blocks keystores. |
| 4 | Git history is clean: I searched `git log -p` for password, secret, api key and token | TO CHECK | Run check A below and write what you found. |
| 5 | Any credential that was ever committed has been rotated | TO CHECK | If check A found nothing: N/A, nothing was ever committed. If it found a real key: rotate it in Supabase and say so here. |

## GitHub Actions

| # | Check | Yes / No / N/A | Evidence |
| --- | --- | --- | --- |
| 6 | No secret value is written literally in any workflow YAML file | Yes | `deploy-web.yml` only references `${{ secrets.SUPABASE_URL }}` and `${{ secrets.SUPABASE_PUBLISHABLE_KEY }}`; there are no literal values. |
| 7 | Secrets are stored in repository Actions secrets and read with `${{ secrets.NAME }}` | Yes | Both are repository secrets (Settings > Secrets and variables > Actions), read in the *Build web* step's `env:` and passed with `--dart-define`. |
| 8 | No workflow step echoes, dumps or debug-prints a secret, and I opened a recent run's log to confirm | TO CHECK | Run check B below. The workflow's only `echo` lines print "ready" flags and notices, never a secret. |
| 9 | If I build a signed APK: the keystore is a base64 secret decoded to a file at build time, never printed | N/A | Web only; the workflow builds `flutter build web` and no APK. |
| 10 | Uploaded build artifacts contain no key file, keystore or generated config | Yes | The only artifact is `build/web` for GitHub Pages. It contains the Supabase URL and publishable key compiled into the app, which are public by design (the database rules protect the data). There is no `.env`, key file, keystore or secret key in it. |
| 11 | Third-party actions are pinned to a commit SHA, not a moveable tag | Yes | Fixed during this check: all four actions (`checkout`, `flutter-action`, `upload-pages-artifact`, `deploy-pages`) were on tags like `@v7`; they are now pinned to commit SHAs, with the tag kept as a comment. Commit: PIN_COMMIT_LINK |
| 12 | Secret scanning and push protection are enabled on the repository | TO CHECK | Do check C below. |

## Backend and security rules

| # | Check | Yes / No / N/A | Evidence |
| --- | --- | --- | --- |
| 13 | Firestore and Storage rules are not left open to anyone; they require an authenticated user | Yes | Supabase, not Firestore. Both Storage buckets (`memory-photos`, `avatars`) are private, and every Storage policy is `to authenticated`. |
| 14 | Rules restrict a user to their own documents where that makes sense | Yes | Every table row is visible only to the two members of its couple; only the author can edit or delete a memory or savings entry; profile photos go only into your own folder. `supabase/test/rls_test.py` runs 61 checks that try to break these rules, and all pass. |
| 15 | If Supabase: Row Level Security is on for every table | TO CHECK | RLS is enabled in `schema.sql` for all six tables. Confirm on the live project with check D below. |
| 16 | Firebase and Google API keys are restricted in the Google Cloud console to the APIs and app they are for | N/A | No Firebase and no Google API keys. Google Fonts are loaded without a key. |
| 17 | I opened the app signed out and confirmed I could not read or write data I should not | TO CHECK | Run check E below. The automated tests also confirm a signed-out visitor sees 0 rows and cannot call the pairing or favourite functions. |
| 18 | Seed and sample data is invented, not real people's data | Yes | There is no seed data file. Screenshots, the demo and testing use invented test accounts with made-up emails. Screenshots showing real names were not committed. |

## Input and app surface

| # | Check | Yes / No / N/A | Evidence |
| --- | --- | --- | --- |
| 19 | Input is validated before it is written, not only styled as valid in the UI | Yes | Checked in the app and again in the database: length limits on names, titles, captions and notes; no future memory dates or birthdays; savings and budgets must be positive. Photo size and type limits were app-only, so I added them to the Storage buckets (migration 005). |
| 20 | Nothing secret is recoverable from the built app, since a shipped binary can be unpacked | Yes | Only the Supabase URL and publishable key are in the build, and both are meant to be public. The secret (`service_role`) key is not used anywhere in the project. |

## Repository and privacy

| # | Check | Yes / No / N/A | Evidence |
| --- | --- | --- | --- |
| 21 | No student number, personal email, phone number or home address in the repository or in commit messages | TO CHECK | Run check F below. |
| 22 | No classmate's personal data in the repository | TO CHECK | Run check G below. |
| 23 | Dependencies come from pub.dev, and `build/` and `.dart_tool/` are gitignored | Yes | Every package in `pubspec.yaml` comes from pub.dev (`supabase_flutter`, `google_fonts`, `image_picker`, `shared_preferences`, `device_preview`), and `.gitignore` lists `build/` and `.dart_tool/`. |
| 24 | Images, fonts and other assets are mine, licensed, or credited | Yes | Fonts are Poppins and Inter (SIL Open Font License, via Google Fonts, credited in the README); icons are Flutter's Material icons; mockups and screenshots are my own. |
| 25 | Repository visibility is deliberate, and I checked it after my last push | TO CHECK | Do check H below. |

## Anything I found and fixed

<!-- Draft from what was actually found. Rewrite it in your own words, and add anything checks A to H turn up. -->

This checklist found three things I did not know about. My workflow's actions were on moveable tags like `@v7`, so a changed action could have run in my build; I pinned all four to commit SHAs. The photo size and file-type limits only existed in the app, so someone calling the API directly could skip them; I added the same limits to both Storage buckets. FINDING_FROM_CHECK_F
