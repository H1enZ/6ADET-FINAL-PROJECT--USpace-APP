# USpace: A private space for two - Documentation

## 1. Overview
USpace is a private web and mobile app for couples, including long-distance ones.
Two partners pair their accounts with a 6-character invite code and share one space that nobody else can see: a shared timeline of memories, a bucket list with savings goals, an anniversary countdown, and a profile for each partner. Every row of data is protected in the database so that only the two members of a couple can read it.

## 2. Setup and installation
Every step to get the app running from nothing, in order:

- The Flutter and Dart versions you built with: Flutter 3.47.5 (stable channel), Dart SDK ^3.8.0 (set in `pubspec.yaml`).
- How to get the code (clone):
  `git clone https://github.com/H1enZ/6ADET-FINAL-PROJECT--USpace-APP.git`
  `cd 6ADET-FINAL-PROJECT--USpace-APP`
- `flutter pub get` and dependencies:
  Run `flutter pub get` to download the required dependencies. Based on current features, the app relies on:
  - `supabase_flutter`: Sign-in, the Postgres database, private photo storage and realtime updates.
  - `google_fonts`: The Poppins and Inter fonts from the design system.
  - `image_picker`: Choosing photos for memories and profile pictures (works on web and phones).
  - `shared_preferences`: Remembering the Light / Dark / System theme choice on the device.
  - `device_preview`: Phone frame for web-based device testing.
  - `cupertino_icons`: Default UI icons.
- Database setup (once):
  In a free Supabase project, open **SQL Editor**, paste the whole of `supabase/schema.sql` and click **Run**. This creates the tables, the row-level security policies, the pairing functions and the private photo buckets. Then go to **Authentication > Sign In / Providers > Email** and turn off **Confirm email** so test accounts can sign in straight away.
- Configuration:
  Create a `.env` file in the root directory based on `.env.example`. Populate it with your own values from **Supabase > Project Settings > API Keys** (never commit this file; it is already git-ignored):
  ```env
  SUPABASE_URL=
  SUPABASE_PUBLISHABLE_KEY=
  ```
  Only the publishable key belongs in the app. The secret (`service_role`) key must never be used.

## 3. How to run it
To run the app in Chrome with your configuration, use the following command:
```bash
flutter run -d chrome --dart-define-from-file=.env
```
Once running, Chrome opens with the app inside a phone frame and shows the splash screen: the wax seal, "USpace" and "Checking your session…". When it is ready it says "Tap anywhere to continue"; tapping opens the Sign in screen.

If you see "This build has no Supabase settings", the two values did not reach the app. Check that `.env` is in the project folder and that both names are spelled exactly as above.

The live version is deployed automatically to GitHub Pages on every push, using the same two values stored as repository secrets.

## 4. Features and usage
- Splash (Session Check): Shows the wax seal while it checks for a saved session. Signed-out users tap anywhere to continue; signed-in users go straight to Pair or Home.
- Authentication (Sign in / Create account): One form with two modes. Creating an account asks for a name, email and a password of at least 8 characters.
- Pairing (Pair with your partner): Start a space (optionally with your anniversary date) to get a 6-character invite code, or join your partner's space with their code. A couple is always exactly two people.
- Global Navigation (App Shell): A bottom navigation bar with five tabs on phones (Home, Timeline, Love Notes, Bucket List, Profile) and a side rail on screens 840 px and wider.
- Home: Both partners' names, the invite code until the partner joins, an anniversary countdown card with a progress ring, birthday countdowns, and the latest memory.
- Timeline: Shared memories with a photo, caption and date, filtered by year. Either partner can favourite a memory with the heart; only the person who added it can delete it. Tapping a memory opens it full size.
- Bucket List: Things to do together, each with an optional location (country or state plus a specific spot, e.g. "Kyoto, Japan (Arashiyama Bamboo Grove)"), a budget, and a target date. Items can be ticked done, filtered by To do / Done / All, and deleted with a swipe.
- Savings Log (Bucket item page): Either partner logs money they have put aside toward an item. The app adds it up against the budget, shows a progress bar and the amount to save each month to reach the goal by the target date. No real money moves through the app; the savings stay in the couple's own bank or e-wallet account.
- Profile: Change your photo and name, add your birthday (with a countdown for both partners), see your partner, and choose Light, Dark or System appearance. Sign out is here too.
- Love Notes: Placeholder tab marked "Being built".

## 5. Project structure
```text
6ADET-FINAL-PROJECT--USpace-APP/
├── .github/
│   └── workflows/
│       └── deploy-web.yml
├── docs/
│   ├── assets/
│   ├── documentation/
│   ├── screenshots/
│   ├── 01-proposal.md
│   ├── 02-mockup.md
│   ├── 03-design-system.md
│   ├── 04-weekly-reports.md
│   ├── 05-demo-video.md
│   ├── 06-security-and-privacy.md
│   └── 07-documentation-log.md
├── lib/
│   ├── models/
│   │   ├── bucket_contribution.dart
│   │   ├── bucket_item.dart
│   │   ├── couple.dart
│   │   ├── memory.dart
│   │   └── profile.dart
│   ├── screens/
│   │   ├── add_memory_sheet.dart
│   │   ├── bucket_item_detail_screen.dart
│   │   ├── bucket_item_sheet.dart
│   │   ├── bucket_list_screen.dart
│   │   ├── coming_soon_screen.dart
│   │   ├── config_missing_screen.dart
│   │   ├── home_screen.dart
│   │   ├── main_shell.dart
│   │   ├── memory_detail_screen.dart
│   │   ├── pair_screen.dart
│   │   ├── profile_screen.dart
│   │   ├── sign_in_screen.dart
│   │   ├── splash_screen.dart
│   │   └── timeline_screen.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── bucket_service.dart
│   │   ├── couple_service.dart
│   │   ├── memory_service.dart
│   │   ├── profile_service.dart
│   │   └── theme_service.dart
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_spacing.dart
│   │   ├── app_theme.dart
│   │   └── app_typography.dart
│   ├── utils/
│   │   ├── anniversary.dart
│   │   └── money.dart
│   ├── widgets/
│   │   ├── atoms/
│   │   │   ├── app_button.dart
│   │   │   ├── app_text_field.dart
│   │   │   ├── avatar_circle.dart
│   │   │   ├── filter_pill.dart
│   │   │   ├── seal_badge.dart
│   │   │   ├── section_label.dart
│   │   │   └── unlock_ring.dart
│   │   ├── molecules/
│   │   │   ├── countdown_card.dart
│   │   │   └── memory_card.dart
│   │   └── organisms/
│   │       └── app_shell.dart
│   ├── config.dart
│   └── main.dart
├── supabase/
│   ├── migrations/
│   │   ├── 002_memory_favourite.sql
│   │   ├── 003_bucket_details_and_savings.sql
│   │   ├── 004_profile_birthday_and_photo.sql
│   │   └── 005_photo_upload_limits.sql
│   ├── test/
│   │   ├── README.md
│   │   ├── rls_test.py
│   │   └── supabase_mock.sql
│   └── schema.sql
├── test/
│   ├── anniversary_test.dart
│   ├── bucket_item_test.dart
│   ├── memory_card_test.dart
│   ├── money_test.dart
│   ├── profile_test.dart
│   ├── seal_badge_test.dart
│   ├── theme_service_test.dart
│   └── widget_test.dart
├── web/
│   ├── index.html
│   └── manifest.json
├── .env.example
├── .gitignore
├── AI-USAGE.md
├── analysis_options.yaml
├── LICENSE
├── pubspec.yaml
├── README.md
├── REPORT.md
└── START-HERE.md
```

**Where state lives:** each screen holds its own state with `setState`. Shared data lives in Supabase and is loaded through `lib/services/`. Supabase keeps the login session, so a returning user stays signed in. The theme choice is the only thing stored on the device.

## 6. Screenshots

All screenshots use invented test accounts and demo pictures.

| Splash | Sign in | Create account |
| --- | --- | --- |
| <img src="/docs/screenshots/01-splash-dark.png" alt="Splash" width="250"> | <img src="/docs/screenshots/02-sign-in-dark.png" alt="Sign in" width="250"> | <img src="/docs/screenshots/03-create-account.png" alt="Create account" width="250"> |

| Timeline | Bucket List | Savings Log |
| --- | --- | --- |
| <img src="/docs/screenshots/04-timeline.png" alt="Timeline" width="250"> | <img src="/docs/screenshots/06-bucket-list.png" alt="Bucket List" width="250"> | <img src="/docs/screenshots/07-bucket-item.png" alt="Savings Log" width="250"> |

| Profile (Light) | Profile (Dark) | Love Notes (placeholder) |
| --- | --- | --- |
| <img src="/docs/screenshots/08-profile-light.png" alt="Profile light" width="250"> | <img src="/docs/screenshots/09-profile-dark.png" alt="Profile dark" width="250"> | <img src="/docs/screenshots/08b-placeholder-love-notes.png" alt="Love Notes placeholder" width="250"> |

## 7. Known issues and next steps
**Known Issues:**
- The Love Notes tab is a placeholder; notes and Time Capsules are not built yet, although their table and security rules already exist in the database.
- A memory can hold only one photo, and a memory cannot be edited after it is saved (only deleted).
- Partner changes do not update live: the first partner has to pull down to refresh to see that the second one joined or added something.
- There is no password reset or "Forgot password?" link yet.
- The Home screen from this week was not captured before it was redesigned, so it has no screenshot here.
- The setup steps have been tested through the automatic GitHub build, not yet on a fresh local machine.
- After a new deploy, the browser can keep showing the old version until the site data is cleared or a private window is used.

**Next Steps:**
- Redesign Home into a shared space: a personalised greeting, today's mood for both partners, a daily question with answers, countdowns to special dates, and a recent activity feed.
- Build Love Notes with Time Capsules that stay sealed for both partners until a chosen date.
- Upgrade the Timeline into a scrapbook-style vertical timeline with multiple photos, a story, location, tags, filters and editing.
- Build a private realtime chat between the two partners.
- Add a "Let's work it out" space for disagreements and comfort, with safety guidance.

## AI usage
This repository includes an `AI-USAGE.md` file recording how AI was used during development, where the AI got things wrong, and which parts of the code were written by me.
