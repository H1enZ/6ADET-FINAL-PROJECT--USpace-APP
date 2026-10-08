# AI usage

This project was built with AI assistance, mainly **Claude Code** (Anthropic) and **OpenAI Codex**, under my direction. This file is the record: how I used AI, where it was wrong, and who wrote what. I want to be accurate about its history: I started it from the course template on 20 September, but I did not update it during Weeks 1 and 2, and wrote most of it on 8 and 9 October from my notes, my commit history and the AI conversations. Every entry links a real commit, so each one can be checked against the repository.

Live demo: https://h1enz.github.io/USpace/

Commit links use the repository https://github.com/H1enZ/USpace

## 1. How I used AI

### 2026-09-28 - Database with row-level security

- **Tool:** Claude Code
- **What I asked for:** A Supabase schema for a couples app: couples, profiles, memories, notes, bucket items, pairing by invite code, a private photo bucket, and security so only the two partners can see their rows.
- **What it gave back:** `supabase/schema.sql` and a test suite that tries to break the rules (another couple reading rows, a third person joining, faking the author, opening a Time Capsule early).
- **What I kept, what I changed, and why:** I kept the design, because the privacy rule lives in the database and a screen bug cannot leak data. I made it run the 33 tests before I ran the SQL on Supabase. Later weeks grew the tests as new tables were added.
- **Commit:** https://github.com/H1enZ/USpace/commit/121ef38

### 2026-09-28 - Theme and shared widgets from my design system

- **Tool:** Claude Code
- **What I asked for:** Turn `docs/03-design-system.md` into a Flutter theme and reusable widgets.
- **What it gave back:** Colour schemes, type scale, spacing, and atoms/molecules/organisms (button, text field, countdown card, app shell).
- **What I kept, what I changed, and why:** I kept the structure. In October I replaced the Poppins/rose look with the deep plum, cocoa and cream direction with Playfair Display and Inter, once the app felt too generic.
- **Commit:** https://github.com/H1enZ/USpace/commit/d677a3d

### 2026-09-29 - Timeline and memories

- **Tool:** Claude Code
- **What I asked for:** Memories with a photo, caption and date in the private bucket, a year filter, a detail page, and a favourite that either partner can set.
- **What it gave back:** The Memory model and service, the Timeline, the add-memory sheet and the detail screen, plus migration 002 for favourites.
- **What I kept, what I changed, and why:** I kept it and later asked for a full scrapbook: up to 10 photos, story, location, tags, editing by both partners, and in October a zoomable corkboard canvas with Polaroids, tape and decorations.
- **Commit:** https://github.com/H1enZ/USpace/commit/5d680ca

### 2026-09-30 - Home, moods, daily question and chat database

- **Tool:** Claude Code
- **What I asked for:** A Home page with greeting, mood, daily question, countdowns, activity feed and quick actions, and the database for chat, moods and affection.
- **What it gave back:** Migration 006, the services, and the new Home.
- **What I kept, what I changed, and why:** I kept the data model. I rewrote the mood rules myself in the prompts: picking a mood shares it automatically, there is no "Share mood" button, and matching moods merge into one state while notes never merge.
- **Commit:** https://github.com/H1enZ/USpace/commit/215a758

### 2026-10-02 to 10-05 - Therabot

- **Tool:** Claude Code (Edge Function and Flutter UI), Groq for the model behind it
- **What I asked for:** A calm AI helper for couples with a private mode and a shared reflection mode, where private words never reach the partner.
- **What it gave back:** A Supabase Edge Function, the guided chat, private next steps, and migrations 011, 016 and 017.
- **What I kept, what I changed, and why:** I kept the privacy split and asked for the quietest screen in the app with minimal decoration, so it feels safe and not like a game.
- **Commit:** https://github.com/H1enZ/USpace/commit/085ad93

### 2026-10-04 - Time Capsules

- **Tool:** Claude Code
- **What I asked for:** Capsules sealed until a chosen date, photo first and letter second, with a ceremony when opened.
- **What it gave back:** A secure data model (migration 014 and an Edge Function that serves the photo only after unlock), then the vintage parchment and candle-wax redesign.
- **What I kept, what I changed, and why:** I kept the design. I asked for follow-up fixes where the security was not tight enough (see Case 3 below).
- **Commit:** https://github.com/H1enZ/USpace/commit/59f786b

### 2026-10-06 to 10-07 - UI redesign program (batches 1 to 10)

- **Tool:** Claude Code, with Figma and Playwright for reference and browser testing
- **What I asked for:** A consistent romantic, warm, private look across Home, Chat, Timeline, Love Notes, Time Capsules, Therabot, Bucket List and Profile, and one set of loading, empty and error states.
- **What it gave back:** The redesign in ten focused batches, each tested on its own before the next.
- **What I kept, what I changed, and why:** I reviewed each batch against my design rules (no typed emoji as icons, calm motion, respect reduced motion) and asked for changes where it did not match.
- **Commit:** https://github.com/H1enZ/USpace/commit/7c1ce64

### 2026-10-08 - Realtime refactor and security audit

- **Tool:** Claude Code
- **What I asked for:** Clean up the code, make updates live without refreshing, then audit the security without changing anything.
- **What it gave back:** One shared couple context, one live-update service (`couple_sync.dart`), faster font and icon loading, the largest files split up, and a written audit with no critical or high findings and three medium ones.
- **What I kept, what I changed, and why:** I kept the refactor, which is tagged `v1.0-refactor-stable`. I asked for the fixes to go in phases, DEV first, and production only on my say-so.
- **Commit:** https://github.com/H1enZ/USpace/commit/a49f3dd

## 2. Where the AI got it wrong

### Case 1 - The wrong stack

- **What it gave me:** A complete Python/Flask app, after I answered "Python backend + frontend" to a quick question.
- **What was wrong with it:** My own proposal said Flutter and Supabase, and GitHub Pages cannot run a Python server, so the live link could never have worked. The AI built exactly what I said, without checking it against my proposal or the course template.
- **What I did instead:** Threw it away and rebuilt on Flutter + Supabase. Lesson: the AI follows my answer, so the answer has to be checked against my own documents first.
- **Commit:** https://github.com/H1enZ/USpace/commit/121ef38 (the first commit of the real stack)

### Case 2 - A splash screen that did not match my mockup

- **What it gave me:** A splash that flashed for under a second and looked like the sign-in screen. When rebuilt, everything was stuck to the left.
- **What was wrong with it:** It ran without errors but ignored my mockup (wax seal, tagline, loading dots). The code does not know what my design looks like.
- **What I did instead:** Compared the live app with my mockup, asked for the wax seal, a wait-for-tap, and centring.
- **Commit:** https://github.com/H1enZ/USpace/commit/15bb2d6 and https://github.com/H1enZ/USpace/commit/ff8414d

### Case 3 - A sealed Time Capsule that was not fully sealed

- **What it gave me:** A capsule model where the photo could still be changed on a capsule that was already sealed, and a cancel flow that skipped the grace-period reopen.
- **What was wrong with it:** Sealing is the whole point of a Time Capsule. Letting the content change after sealing, or cancelling without reopening, breaks the promise to both partners.
- **What I did instead:** Asked for the rule to be enforced in the database: a sealed capsule must be reopened before its photo can change, and a capsule in its grace period is reopened before it is cancelled.
- **Commit:** https://github.com/H1enZ/USpace/commit/d237dfa and https://github.com/H1enZ/USpace/commit/f5904a4

### Case 4 - Realtime channels anyone could join

- **What it gave me:** Live updates through broadcast channels that were public.
- **What was wrong with it:** The audit found that anyone who knew a channel name could listen to or send on it. That is not acceptable for a private couples app.
- **What I did instead:** Asked for private channels that only the two partners can join, migration 021, and a test that proves another couple and signed-out visitors cannot join. It is on DEV and being rolled out to production in stages.
- **Commit:** https://github.com/H1enZ/USpace/commit/a49f3dd (the realtime service); migration 021 is in `supabase/migrations/`

### Case 5 - My own Bucket List bugs, found in review

- **What it gave me:** This one is mine. My first Bucket List had five bugs, including a Save button that could never be tapped and a text controller disposed while its dialog was still closing.
- **What was wrong with it:** I wrote code that compiled but did not behave. I only found out when a review pointed at them.
- **What I did instead:** Fixed each one and learned why (a button is disabled when its condition can never become true; a controller must outlive the closing animation).
- **Commit:** https://github.com/H1enZ/USpace/commit/66d7f49

### Case 6 - A dead live link and a wrong password in my own documents

- **What it gave me:** A README with the live demo link at the top and a tester password.
- **What was wrong with it:** The repository had been renamed to `USpace`, so the GitHub Pages link returned a 404, and one tester password was missing an "s". The AI wrote what I gave it without testing either.
- **What I did instead:** Opened the live link and signed in as both testers, found both problems, and corrected the README and every document that used them.
- **Commit:** https://github.com/H1enZ/USpace/commit/6ea3f2f

## 3. Who wrote what

### My role: project creator and AI orchestrator

Throughout USpace I was the project creator, AI orchestrator and prompt engineer.

I developed the original concept and decided how the app should look, work and feel. I used Claude Code, together with OpenAI Codex, to turn those ideas into working Flutter features.

My responsibilities:

- Developing the original concept and overall vision of USpace.
- Planning features and defining how they should function.
- Writing detailed prompts and directing AI coding agents.
- Coordinating development between Claude Code and Codex.
- Reviewing AI-generated implementations and requesting improvements.
- Manually organising, replacing and fixing application assets.
- Identifying problems and directing debugging.
- Making final decisions about the design and functionality.

AI generated much of the source code. I was responsible for directing it and deciding what the final product should become.

### Written by me: the Bucket List

- **File:** `lib/models/bucket_item.dart`, `lib/services/bucket_service.dart`, `lib/screens/bucket_list_screen.dart`
- **Commit:** https://github.com/H1enZ/USpace/commit/9db3076 (model, service, tests) and https://github.com/H1enZ/USpace/commit/66d7f49 (the screen)
- **What it does and why it is built this way:** The Bucket List is the part I personally coded. I chose it because it is the simplest feature and its table already existed, so I could focus on how Flutter handles user interaction and stored data. It lets a couple add things they want to do together, filter them (To do / Done / All), tick them off, and swipe to delete.
  - **Model (`bucket_item.dart`):** `BucketItem` is a plain class that mirrors one row of `bucket_items`. `fromMap` turns a database row into an object and treats a missing `is_done` as false, so a null never crashes the screen. I wrote `withDone` instead of a normal `copyWith` because `copyWith` with `??` cannot set a value back to null: unticking an item has to clear `completedAt`, and `?? ` would keep the old date.
  - **Service (`bucket_service.dart`):** the screen never talks to Supabase directly; it calls `BucketService.list`, `add`, `setDone` and `delete`. Each is one query. `list` sorts not-done items first and newest first. I filter by `couple_id` but the real protection is row-level security in the database, which only returns rows of the user's own couple, so a bug in my screen cannot show another couple's list.
  - **Screen (`bucket_list_screen.dart`):** state lives in the screen with `setState`: the list of items and the selected filter. Ticking an item updates the list on screen first so the checkbox feels instant, then saves to the database; if saving fails, it puts the old item back and shows an error. Deleting asks for confirmation first, and checks `mounted` after every `await` so it never touches a screen that has already closed. The add dialog keeps its text controller inside its own widget and disposes it only when the dialog is really gone, which is the fix for the crash described in Case 5.

**What happened after:** I later extended it with a location, a budget and a savings log (migration 003 and the item page, commit 146db7b), and in October the screen was restyled as part of the AI-assisted UI redesign (batch 9, commit fce39b1). The first version and its logic are mine; the later extensions (commit 146db7b) and the restyle were done with AI help, so I do not count them as my own code.

### The AI-written part I understand best

- **File:** `lib/services/couple_sync.dart`
- **Commit:** https://github.com/H1enZ/USpace/commit/a49f3dd
- **What it does and why I kept it:** It is one live-update service for the whole couple. Before, each screen refreshed on its own, so a partner's message or mood only showed after pulling down. Now the app opens two private channels that only the two partners can join, and each screen just says which tables it shows and what to reload. New and edited rows arrive as database changes (row-level security still applies, so a partner only gets rows they could read anyway). Deletes cannot be filtered to one couple, so whoever deletes something sends a small "changed" message naming only the table, and the partner re-reads it. When a dropped connection comes back, every listener reloads once. The AI wrote it; I chose to keep it because it made updates instant, removed duplicated refresh code, and let me explain to myself why private data cannot leak through it.

### AI-generated and AI-assisted code

The remaining major features were developed primarily with Claude Code and OpenAI Codex under my direction: authentication, partner pairing, Home, Chat, Timeline, Memories, Love Notes, Moods, Time Capsules, Therabot and the supporting database. For these I provided the requirements, designed the intended experience, reviewed the output and directed the revisions.

I acknowledge that writing prompts and reviewing generated code is different from personally writing source code.

## 4. Reflection

Looking back at the entire development process, I can say that creating USpace was both exciting and challenging.

There were moments when I felt proud because I could finally see the application I had imagined becoming real. There were also moments when I felt frustrated because something wasn't working, the design didn't match my expectations, or I had to repeat a process several times.

But despite those challenges, I learned a lot about project planning, application development, prompt engineering, debugging, security, and decision-making. Most of all, I learned to maximize AI, embrace AI, and orchestrate AI well.

What made this project meaningful to me was that it started with my own idea. I wanted to create something that could help couples feel appreciated, remembered, and connected, even when they were far away from each other.

Seeing that idea turn into an actual application was a rewarding experience.

I'm proud of what I accomplished, but I also recognize that I still have a lot to improve, especially when it comes to writing and understanding code independently.

I don't consider USpace a perfect application, and I know there are still issues that need to be addressed. However, I see those imperfections as opportunities to learn.

My role in this project was to create the vision, direct the development, evaluate the results, and personally implement the Bucket List feature.

I learned to maximize AI, embrace AI, and orchestrate AI well, and honestly, it changed how I feel about it. At the start I was a little embarrassed to depend on AI so much, as if it meant the work was not really mine. Over time that feeling turned into something closer to pride. Once I stopped hiding it and embraced it, with Claude Code as my lead and OpenAI Codex as a second opinion, I could finally put all my energy into the part that mattered: what USpace should feel like. It was frustrating when the first results were generic, and it was a relief when I wrote down my design, mood, security and Git rules and the output suddenly matched what I had imagined. That is when I understood what it means to maximize AI: it does its best work when I give it clear direction, small steps and a test after every batch. And orchestrating it was the most satisfying part. Deciding the order, giving each tool its role, and saying "no, that is not right yet" when something was wrong made me feel like the director of the project and not just someone typing prompts.

I also see this as more than a school project. The job market is changing fast, and AI is already part of how software gets built. I would rather not spend my time fighting it or pretending it does not exist. I would rather embrace it and learn to use it as early and as well as I can, so that by the time I am looking for work I already know how to direct it, check it and take responsibility for what it produces.

If there's one thing I'll take away from this experience, it's that AI can help me build what I imagine, but it's still my responsibility to understand what I'm building, question the results, and keep learning along the way.

For me, that's the most important lesson I gained from creating USpace.

More in [docs/REFLECTION.md](docs/REFLECTION.md).
