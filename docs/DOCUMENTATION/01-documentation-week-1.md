# USpace: A private space for two - Documentation

## 1. Overview
USpace is a private web and mobile app for couples, including long-distance ones.
Two partners pair their accounts with a 6-character invite code and share one space that nobody else can see, starting with a countdown to their anniversary. The shared timeline, love notes, Time Capsules and bucket list are planned and are being built week by week. From the first week, every table is protected in the database so that only the two members of a couple can read its rows.

## 2. Setup and installation
Every step to get the app running from nothing, in order:

- The Flutter and Dart versions you built with: Flutter 3.47.5 (stable channel), Dart SDK ^3.8.0 (set in `pubspec.yaml`).
- How to get the code (clone):
  `git clone https://github.com/H1enZ/6ADET-FINAL-PROJECT--USpace-APP.git`
  `cd 6ADET-FINAL-PROJECT--USpace-APP`
- `flutter pub get` and dependencies:
  Run `flutter pub get` to download the required dependencies. Based on current features, the app relies on:
  - `supabase_flutter`: Sign-in, the Postgres database and the saved login session.
  - `google_fonts`: The Poppins and Inter fonts from the design system.
  - `device_preview`: Phone frame for web-based device testing.
  - `cupertino_icons`: Default UI icons.
- Database setup (once):
  In a free Supabase project, open **SQL Editor**, paste the whole of `supabase/schema.sql` and click **Run**. This creates the tables, the row-level security policies, the pairing functions and a private photo bucket. Then go to **Authentication > Sign In / Providers > Email** and turn off **Confirm email** so test accounts can sign in straight away.
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
- Splash (Session Check): Shows the wax seal from the design system while it checks for a saved session. Signed-out users tap anywhere to continue; signed-in users go straight to Pair or Home.
- Authentication (Sign in / Create account): One form with two modes. Creating an account asks for a name, email and a password of at least 8 characters. A returning user stays signed in.
- Pairing (Pair with your partner): Start a space (optionally with your anniversary date) to get a 6-character invite code, or join your partner's space with their code. A couple is always exactly two people; a third person cannot join.
- Global Navigation (App Shell): A bottom navigation bar with five tabs on phones (Home, Timeline, Love Notes, Bucket List, Profile) and a side rail on screens 840 px and wider.
- Home: Both partners' names, the invite code with a copy button until the partner joins, and an anniversary countdown card with a progress ring that fills through the year. Tapping the card sets or changes the anniversary. Pull down to refresh.
- Profile: Shows your name and email, with Sign out.
- Timeline, Love Notes and Bucket List: Placeholder tabs marked "Being built". Their database tables and security rules already exist.

## 5. Project structure
```text
6ADET-FINAL-PROJECT--USpace-APP/
├── .github/
│   └── workflows/
│       └── deploy-web.yml
├── docs/
│   ├── assets/
│   ├── DOCUMENTATION/
│   ├── screenshots/
│   ├── 01-proposal.md
│   ├── 02-mockup.md
│   ├── 03-design-system.md
│   ├── 04-weekly-reports.md
│   ├── 05-demo-video.md
│   └── 06-security-and-privacy.md
├── lib/
│   ├── models/
│   │   ├── couple.dart
│   │   └── profile.dart
│   ├── screens/
│   │   ├── coming_soon_screen.dart
│   │   ├── config_missing_screen.dart
│   │   ├── home_screen.dart
│   │   ├── main_shell.dart
│   │   ├── pair_screen.dart
│   │   ├── profile_screen.dart
│   │   ├── sign_in_screen.dart
│   │   └── splash_screen.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   └── couple_service.dart
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_spacing.dart
│   │   ├── app_theme.dart
│   │   └── app_typography.dart
│   ├── utils/
│   │   └── anniversary.dart
│   ├── widgets/
│   │   ├── atoms/
│   │   │   ├── app_button.dart
│   │   │   ├── app_text_field.dart
│   │   │   ├── seal_badge.dart
│   │   │   ├── section_label.dart
│   │   │   └── unlock_ring.dart
│   │   ├── molecules/
│   │   │   └── countdown_card.dart
│   │   └── organisms/
│   │       └── app_shell.dart
│   ├── config.dart
│   └── main.dart
├── supabase/
│   ├── test/
│   │   ├── README.md
│   │   ├── rls_test.py
│   │   └── supabase_mock.sql
│   └── schema.sql
├── test/
│   ├── anniversary_test.dart
│   ├── seal_badge_test.dart
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

**Where state lives:** each screen holds its own state with `setState`. Shared data lives in Supabase and is loaded through `lib/services/`. Supabase keeps the login session, so a returning user stays signed in.

## 6. Screenshots

All screenshots use invented test accounts.

| Sign in | Create account | Timeline (placeholder) |
| --- | --- | --- |
| <img src="/docs/screenshots/02-sign-in.png" alt="Sign in" width="250"> | <img src="/docs/screenshots/03-create-account.png" alt="Create account" width="250"> | <img src="/docs/screenshots/08-placeholder.png" alt="Timeline placeholder" width="250"> |

| Love Notes (placeholder) | Bucket List (placeholder) |
| --- | --- |
| <img src="/docs/screenshots/08b-placeholder-love-notes.png" alt="Love Notes placeholder" width="250"> | <img src="/docs/screenshots/08c-placeholder-bucket-list.png" alt="Bucket List placeholder" width="250"> |

The Pair, Home and Profile screens from this week are not shown: the screenshots taken of them contained real names and an email address, so they were left out of this public repository.

## 7. Known issues and next steps
**Known Issues:**
- Timeline, Love Notes and Bucket List are placeholder tabs.
- Home's "Recent memories" always says "No memories yet", because memories cannot be added until the Timeline exists.
- Partner changes do not update live: the first partner has to pull down on Home to see that the second one has joined.
- There is no password reset, and no way yet to edit your name, add a photo or change the theme.
- Sign in and Pair are two separate screens, where the mockup shows them as one.
- The setup steps have been tested through the automatic GitHub build, not yet on a fresh local machine.
- After a new deploy, the browser can keep showing the old version until the site data is cleared or a private window is used.
- The Supabase free tier pauses a project after about a week without use; if the live app cannot sign in, the project may need to be resumed from the dashboard.

**Next Steps:**
- Build the Timeline: memories with a photo, caption and date, stored in the private photo bucket, with favourites for both partners.
- Build the Bucket List, including a location, a budget and a shared savings log for each item.
- Build the Profile: profile photo, editable name, and birthday with a countdown.
- Add a Light / Dark / System theme switch.
- Fill in the security checklist and keep the documentation and screenshots current.

## AI usage
This repository includes an `AI-USAGE.md` file recording how AI was used during development, where the AI got things wrong, and which parts of the code were written by me.
