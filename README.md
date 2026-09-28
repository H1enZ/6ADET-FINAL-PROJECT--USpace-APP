<!--
  This is your project's front page. Replace every placeholder below.
  It is the first thing your instructor and any future employer will read, and
  the live link in it is how your project gets opened for grading.

  New here? Read START-HERE.md first. Delete this comment when you are done.
-->

# USpace

> A private space for two people in one relationship: a shared timeline of memories, love notes, Time Capsules sealed until a chosen date, and a bucket list.

**Live demo:** https://h1enz.github.io/6ADET-FINAL-PROJECT--USpace-APP/
**Demo video:** `docs/demo.mp4` (link it here once it exists)
**Course:** Applications Development and Emerging Technologies (6ADET), Holy Angel University
**Author:** Mikko Panergo

This repository lives in the author's own GitHub account and is public on
purpose. There is no `student.json` here and there should not be one: see
`docs/06-security-and-privacy.md` for what a public repo means for secrets and
personal data.

---

## Screenshots

Put two or three real screenshots at phone size in `docs/assets/`, then replace
this paragraph with them:

```markdown
| Home | Detail | Add |
| --- | --- | --- |
| ![Home](docs/assets/screen-home.png) | ![Detail](docs/assets/screen-detail.png) | ![Add](docs/assets/screen-add.png) |
```

## What it does

- Create an account and pair with your partner using a 6-character invite code. A couple is always exactly two people.
- See how many days you've been together and a live countdown to your next anniversary.
- Keep a shared timeline of memories with photos. *(in progress)*
- Send love notes, or seal one as a Time Capsule that neither of you can open until its date. *(in progress)*
- Keep a shared bucket list of things to do together. *(in progress)*

## Built with

| | |
| --- | --- |
| Framework | Flutter (Dart) |
| State | `setState` |
| Storage | Supabase (Postgres, Auth, Storage) for shared data |
| Other packages | `supabase_flutter` for sign-in and data, `google_fonts` for Poppins and Inter, `device_preview` for the phone frame |

## Running it yourself

You need Flutter (run `flutter --version`) and a free Supabase project.

**1. Set up the database (once).** In the Supabase dashboard, open **SQL Editor**, paste all of `supabase/schema.sql`, and run it. For testing with made-up emails, turn off **Authentication > Sign In / Providers > Email > Confirm email**.

**2. Add your keys.** Copy `.env.example` to `.env` and fill in `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` from **Project Settings > API Keys**.

**3. Run it.**

```bash
flutter pub get
flutter run -d chrome --dart-define-from-file=.env
```

To test pairing, open a second browser profile or an incognito window, sign up with a second email, and join with the code shown on the first account's Home screen.

### Environment variables

This project reads its configuration from a `.env` file that is **not** in the
repository. Copy `.env.example`, fill in your own values, and never commit the
result.

| Variable | What it is | Where to get one |
| --- | --- | --- |
| `SUPABASE_URL` | Your Supabase project's address | Supabase > Project Settings > API Keys |
| `SUPABASE_PUBLISHABLE_KEY` | Public client key; the RLS policies protect the data, not this key | Supabase > Project Settings > API Keys |

For the live demo, the same two names are set as repository secrets and passed in by `.github/workflows/deploy-web.yml`.

## Privacy and secrets

- The app stores each person's email, display name, and everything the couple adds (memories, photos, notes, bucket list) in Supabase.
- Every table and the photo bucket are protected by row-level security in `supabase/schema.sql`: a row is visible only to the two members of the couple it belongs to. Sealed Time Capsules are hidden by the database itself until their unlock time, even from the person who wrote them. Joining a couple is only possible through the invite-code function, never by editing a profile.
- Only the Supabase URL and publishable key are in the build. The `service_role` key is never in the app or the repo.
- All sample data, screenshots and the video use invented names and no real personal information.

## Project documentation

| Document | |
| --- | --- |
| [Proposal](docs/01-proposal.md) | the problem, the users, the scope |
| [Mockup and wireframes](docs/02-mockup.md) | what it looks like, and the screen flow |
| [Design system](docs/03-design-system.md) | colors, type, spacing, components |
| [Weekly reports](docs/04-weekly-reports.md) | what happened each week |
| [Demo video](docs/05-demo-video.md) | the recording and what it shows |
| [Start here](START-HERE.md) | how this repo works (delete once you have read it) |
| [Security and privacy](docs/06-security-and-privacy.md) | the checklist, filled in |

## Status and what is next

Be honest. What works, what is half done, what you would build next. An honest
"known issues" section reads better than a claim the reader disproves in thirty
seconds.

## Credits

- Packages: see `pubspec.yaml`
- Fonts: Poppins and Inter, via Google Fonts (SIL Open Font License)
- People who helped, and how

## AI use

See [AI-USAGE.md](AI-USAGE.md).

## Licence

MIT, see [LICENSE](LICENSE). Change it if you want different terms.
