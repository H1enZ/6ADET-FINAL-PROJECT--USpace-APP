# Security policy

USpace is a private app for two people, so protecting what a couple shares is the main job of the project.

**Live app:** https://h1enz.github.io/USpace/

## How privacy is protected

- **In the database, not only in the screens.** Row-level security is turned on for every table, so a row is visible only to the two members of its couple. A couple is exactly two people, and joining is only possible through the invite-code function.
- **Sealed Time Capsules** stay unreadable to both partners until their unlock time. Their photos are served through an Edge Function, only after unlock.
- **Therabot private talks** are hidden from the partner by policies and column privileges. A shared reflection is written only from short summaries, never from private messages.
- **Photos** live in private storage buckets with size and type limits, and each couple can only reach its own folder.
- **Live updates** use realtime channels that only the two partners can join.
- **Secrets stay out of the app.** Only the Supabase URL and the publishable key are in the build, and the database rules protect the data. The secret (`service_role`) key and the Therabot AI key are server-side only and are never committed.
- **Automated checks.** `supabase/test/` attacks the database rules (reading another couple's rows, joining a full couple, faking an author, opening a capsule early, and more). GitHub secret scanning and push protection are on.

The completed checklist is in [docs/06-security-and-privacy.md](docs/06-security-and-privacy.md).

## Reporting a vulnerability

Please do not open a public issue for a security problem.

1. Open the **Security** tab of this repository and choose **Report a vulnerability** (a private GitHub security advisory), or
2. message the owner, [@H1enZ](https://github.com/H1enZ), on GitHub.

Please include what you found, the steps to reproduce it, and which screen or table it affects. Do not use real people's data. USpace is a student project, so I will reply as soon as I can, but I cannot promise a fixed time.

## Scope

- **In scope:** the live web app, the code in this repository, and the database rules in `supabase/`.
- **Please do not:** test against other people's accounts, try to overload the service, or publish a problem before it is fixed.
- **Test accounts:** the two tester accounts in the [README](README.md#tester-accounts) are there for trying the app. Please do not store real personal information in them.

## Supported versions

Only the latest version on `main`, which is what the live app serves.
