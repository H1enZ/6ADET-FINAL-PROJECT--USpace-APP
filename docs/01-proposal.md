# Proposal

**USpace** — a private app for two people in one relationship.

## The problem, in one sentence

Couples who live apart or keep different schedules have no single private place, separate from social media and group chats, where both partners add to the same memories, dates and notes — and no way to write something that arrives on a date they choose.

## Who it is for

Two partners in one relationship, student-age, including long-distance ones. Every account belongs to exactly one couple of exactly two people.

Today they use a camera roll each, a Messenger or Viber thread where notes are mixed in with everyday chat, a calendar reminder for the anniversary, and date ideas that get forgotten. Nothing is shared in one place, and nothing can be scheduled to arrive later.

## Core features

Estimates are hours, including wiring the screen to storage. Total **54 h**, which fits the term at roughly 6–7 h a week.

| # | Feature | Flutter pieces | Est. |
|---|---|---|---|
| 1 | Sign in & pair two accounts into one couple | `Form`, `TextField`, `Navigator.pushReplacement`, `showDialog`, `supabase_flutter` auth | 8 h |
| 2 | Shared memory timeline (photos) | `ListView.builder`, `Card`, `Image.network`, `image_picker`, `showModalBottomSheet`, `showDatePicker` | 10 h |
| 3 | Love Notes — send, list, favourite | `ListView.builder`, `TextField`, `IconButton`, `StreamBuilder`, `FloatingActionButton` | 6 h |
| 4 | Time Capsule — a note sealed until a chosen date | `Stack`, `CircularProgressIndicator` as the countdown ring, `Timer.periodic`, `showDatePicker`, unlock enforced in the database | 6 h |
| 5 | Home — anniversary countdown and recent memories | `Card`, `DateTime.difference`, `Timer.periodic`, horizontal `ListView` | 3 h |
| 6 | Bucket List | `ListView.builder`, `CheckboxListTile`, `Dismissible`, `showDatePicker` | 4 h |
| 7 | App shell and navigation | `Scaffold`, `NavigationBar` / `NavigationRail`, `IndexedStack`, `Navigator.push` | 2 h |
| 8 | Profile & Settings — name, theme, notification toggle | `SwitchListTile`, light and dark `ThemeData`, `shared_preferences` | 4 h |
| 9 | Supabase setup: tables, row-level security, two-account testing | SQL tables, RLS policies, private storage bucket | 6 h |
| 10 | Testing, sample-data mode, web run-through, bug fixing | sample-data repository, `flutter run -d web-server` | 5 h |

The Time Capsule is the feature the app is named around: a note is sealed, the partner sees a wax seal and a live countdown but never the words, and it opens itself on the chosen date.

## Out of scope, and why

Each of these costs more than a whole ordinary screen, and none of them is needed for the app to work end to end.

1. **Video in the timeline** — `video_player`, larger uploads and its own player screen.
2. **Photo gallery grid** — the timeline already shows every photo; a second view of the same data is presentation, not capability.
3. **Daily affirmation / quote of the day** — nice, but it pushed the sealed-capsule card below the fold on Home.
4. **Push and local notifications** — `flutter_local_notifications` does not run on web, so it needs a stand-in plus a phone recording to demo. The countdown and unlock state are already visible on Home and in Love Notes, so the app is not broken without it.
5. **Profile photo upload and PDF export of the timeline.**

If my weekly hours fall short, the next thing cut is the Time Capsule *polish* — feature 4 becomes a plain date-locked note without the ring animation — never the sign-in or the storage work, because everything else depends on those.

## Data the app remembers, and where it is saved

**Two partners must see the same data**, which rules out anything that lives on one phone. Volume is small: about 20–30 rows and ~20 MB of photos per couple per week, roughly 1,000–1,500 rows a year.

**Choice: Supabase** (hosted Postgres + Auth + Storage) through `supabase_flutter`, with `shared_preferences` on the device for settings only.

Why this and not the alternatives: the data is relational (a couple has two members; memories, notes and bucket items all belong to that couple), and row-level security lets one rule — *a row is visible only if its `couple_id` matches the signed-in user's couple* — protect every table. It also lets the Time Capsule be enforced in the database rather than in the UI, so the lock cannot be bypassed by editing the app. Private storage buckets cover the photos. **The tradeoff accepted:** the app needs a connection to show anything, it depends on a hosted free tier, and a mistake in a policy could expose private data — so policies get tested with two accounts in different couples.

| Thing | Fields | Where it is saved |
|---|---|---|
| Couple | `id`, `anniversary_date`, `pairing_code`, `created_at` | table `couples` |
| Profile | `user_id`, `couple_id`, `display_name`, `avatar_path` | table `profiles` |
| Memory | `id`, `couple_id`, `author_id`, `caption`, `memory_date`, `photo_path`, `created_at` | table `memories`; file in private bucket `memory-photos` |
| Love note | `id`, `couple_id`, `author_id`, `body`, `is_favorite`, `sent_at`, `unlock_at` (null for an ordinary note) | table `notes` |
| Bucket item | `id`, `couple_id`, `title`, `target_date`, `is_done`, `completed_at` | table `bucket_items` |
| Device settings | `theme_mode`, `notifications_enabled` | `shared_preferences` |
| Session | access and refresh tokens | handled by `supabase_flutter` |

**Not in the repository:** the Supabase URL and anon key live in a git-ignored `.env` locally and in repository secrets for the deploy. The `service_role` key is never in the app or the repo, and no real photos, names or messages are committed — sample-data mode uses placeholder images and invented names.

## Risks

**1. Private data is only as safe as my security policies.** Smaller than at prelim, because Supabase handles sign-in and encryption so I no longer build them. Bigger in a new way, because protection now depends on me writing the policies correctly and one wrong rule exposes a couple's data.
*First step:* write the policies for `couples`, `memories`, `notes` and the photo bucket, then test with two accounts in different couples — each must see zero of the other's rows and files. **By 4 Oct 2026.**

**2. The two-person, two-device flow, and the Time Capsule.** It can only be tested by being signed in as two users at once, and the unlock rule has to hold on the server, not just in the UI. Time Capsule was not in the prelim and is the hardest single screen.
*First step:* create two test accounts, run one in Chrome and one in a second browser profile, send a sealed note with an unlock time two minutes out, and confirm the recipient cannot read it early. **By 11 Oct 2026.**

**3. It has to open in a browser.** Everything device-only degrades to sample data rather than crashing: camera capture falls back to the file picker, and notifications (if built) fall back to an in-app banner behind a `NotificationService` interface. The `device_preview` wrapper stays.
*First step:* click through every screen with `flutter run -d web-server` on sample data. **By 4 Oct 2026.**

## Changes since the last version

**20 Sep 2026 — proposal v2, written after building m4a4 and m5a5.**

- **Storage named.** The prelim said "encrypted storage" and listed state per screen. Module 5 ended with everything disappearing on restart, and two partners have to see the same data, so it is now Supabase for shared data and `shared_preferences` for two device settings.
- **Scope re-scored against real hours.** Six loosely-sized features became eight sized ones plus setup and testing (54 h). Writing out the actual widgets showed video and notifications each cost more than a whole screen, so both moved out of scope.
- **Time Capsule added, then simplified.** It was not in the prelim. The countdown ring is a `CircularProgressIndicator`, not a custom painter, which keeps it at 6 h.
- **Screens grew from 5 to 9.** The five tabs plus Splash, Sign in & Pair, Time Capsules and Capsule — locked. Shared storage means every user needs an account and a way to pair.
- **Name kept as USpace.** "Our Story" and "SEQUEL" were tried during design and dropped; renaming costs a pass over every document for no functional gain.
- **Risks doubled.** The prelim's one risk was reframed as policy correctness, and two-user testing was added, each with a date rather than "eventually".
