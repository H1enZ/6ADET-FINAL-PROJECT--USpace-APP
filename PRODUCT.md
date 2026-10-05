# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

Flutter web, deployed to GitHub Pages and designed phone-first. On desktop it shows inside a phone frame (`device_preview`), and from 840 px wide the bottom bar becomes a side rail. There is no `android/` or `ios/` build.

## Users

Two partners in one relationship, mostly student-age and often long-distance or on different schedules. Each account belongs to exactly one couple of exactly two people, and a third person can never join.

Today they spread their relationship across a camera roll each, a Messenger or Viber thread where notes get lost in everyday chat, a calendar reminder for the anniversary, and date ideas they forget. USpace gives them one private place both of them add to.

**Real couples come first.** Design decisions serve partners who actually use the app. It is also the 6ADET final project (Holy Angel University), but the grade follows from it working for real couples, not the other way round. *(Confirmed by the user, 2026-10-06.)*

## Product Purpose

USpace is a shared, private space for one couple. Success means both partners come back to it on their own: to talk, to share how they feel, to save memories, and to leave each other things worth finding later.

## Positioning

- **Built for exactly two people.** Everything in the app assumes two people: reactions show "you" and the partner by name, and read receipts and presence are about your partner, not a group.
- **Privacy is enforced by the server, not the screen.** Row-level security keeps every row visible only to its own couple. A sealed Time Capsule stays hidden from both partners until it unlocks, and that is enforced in the database.
- **Things that arrive later.** The Time Capsule, a note sealed until a chosen date, is the feature the app is built around. Social apps and chat threads can't truthfully offer this.

## Operating Context

- Used on phones, often apart and across time zones, in short moments during the day (chat, mood check-ins, reactions) and longer ones (writing a love note or capsule, arranging the timeline scrapbook).
- Both partners see the same data live. Realtime updates (chat, reactions, timeline edits) are part of the experience.
- It needs a connection: Supabase is hosted, and nothing works offline.

## Capabilities and Constraints

**What it does now:** sign in and pair with an invite code; Home with the anniversary countdown, mood sharing and quick actions; a private realtime chat with USpace reactions, photos, editing and deleting; Love Notes with favourites; Time Capsules (sealed, counted down, opened with a wax-seal animation); a Timeline scrapbook that can be edited; a Bucket List with savings contributions; Important Dates; daily questions; Notifications; hug and kiss gestures; and Therabot / "Work it out" for working through a disagreement, with private reflection and next steps.

**Technical constraints:**
- Flutter (Dart ≥ 3.8) with Supabase for Postgres, Auth, Storage and Realtime.
- Each screen keeps its own state with `setState`, and all backend calls go through `lib/services/`.
- Device-only features have to fall back gracefully on web (for example, the file picker instead of the camera, and in-app notices instead of push).

**Terminology:** "couple", "partner", "space" (as in "Start our space"), "Love Note", "Time Capsule", "Timeline", "Bucket List", "Work it out".

**Undecided:** which identity elements are binding (see Brand Commitments).

## Brand Commitments

The user has not yet confirmed which of these are binding. They are recorded as **existing assets, not commitments**, so future work should ask before replacing any of them:
- the name **USpace** and its wordmark (`lib/widgets/brand/uspace_wordmark.dart`);
- the **wax seal** on the splash screen and on Time Capsules;
- a warm, plain voice in the copy (e.g. "Only the two of you can ever read this chat.");
- "Only you two" as a recurring privacy promise.

## Evidence on Hand

- Docs: `docs/01-proposal.md`, `docs/03-design-system.md`, `docs/06-security-and-privacy.md`, `README.md`, `AI-USAGE.md`.
- Security: `supabase/test/` (RLS checks across two couples).
- Screenshots: `docs/screenshots/`.
- **There are no real testimonials, user counts or usage data.** All sample data and test accounts are invented, and future work must not make up any of these.

## Product Principles

1. **Two people, never a crowd.** Every feature, label and state is written for one partner and the other, by name.
2. **Privacy is a promise you can rely on.** Claims like "only you two" have to be backed by the server rules, not just the interface.
3. **Warmth without noise.** Things done many times a day stay quick and calm; celebration is saved for rare moments (opening a capsule, a first message).
4. **Anything that arrives later must arrive reliably.** Sealed and scheduled content works exactly as promised, on time, and is never readable early.

## Accessibility & Inclusion

Nice to have, not a blocking requirement *(confirmed by the user, 2026-10-06)*. Keep the existing reduced-motion handling, screen-reader labels and 48 dp touch targets when changing a screen, but they should not block new features.
