# Project Journal

## Week 3 (September 28, 2026 to October 8, 2026)

*Written on 8 October 2026.*

Week 3 was the biggest week. USpace stopped being a prototype and became the app I had in mind: a new Home, private chat, moods, Love Notes, Time Capsules, Therabot, a scrapbook Timeline, a full redesign, and finally a security audit. It was also the week I learned the most about directing AI instead of just using it.

### 1. From a feature list to a feeling

At the start of the week I asked for features. By the middle I was asking for a feeling: romantic, warm, private, cute but polished. I wrote that down as design rules (deep plum, cocoa, dusty rose, cream; Playfair Display for headings and Inter for body; no typed emoji as icons; calm motion). Once the rules existed, the AI's output got much more consistent, because it had something to check against instead of my mood that day.

### 2. Each screen has its own personality

I gave every screen a different personality on purpose. Timeline is a scrapbook with Polaroids, tape and movable memories. Love Notes feel like paper letters. Time Capsules are ceremonial, photo first and letter second. Therabot is the quietest screen. Chat is clean and modern. This was the hardest design decision of the week, because the temptation is to make everything look the same.

### 3. The mood rules

Picking a mood shares it with your partner automatically, with no "Share mood" button. If your moods differ they are shown separately; if they match they merge into one shared state, but notes never merge. These rules came from asking how it should feel for two people, not how it is easiest to build. They were more work for the AI, and I think they are the nicest part of the app.

### 4. Security is not a screen

Time Capsules made it obvious. A sealed capsule has to be hidden from both partners until its unlock time, so the rule must live in the database, not in the screen. The AI's first version let a sealed capsule's photo still change, and I had to ask for that to be enforced server-side. Therabot has the same problem: what you say in private must never reach your partner, even if the screen has a bug.

At the end of the week I asked for a security audit that changed nothing. It found no critical or high issues and three medium ones: email confirmation is off on the live project, some realtime channels were public, and pairing codes. Fixing them is a staged process, DEV first, and production only after I say so. That was uncomfortable, because I wanted to be finished, but I would rather ship it fixed than fast.

### 5. Directing two AI tools

I used Claude Code as the lead and OpenAI Codex as a second opinion and implementation worker. The trick was to keep roles clear: Claude plans and reviews, Codex implements when asked, and I decide. Neither pushes, deploys or touches production unless I say so. I wrote those rules into project instruction files so I would not have to repeat them every session.

### 6. Small batches beat big ones

The redesign went in ten batches, one screen area at a time, each tested before the next. When I asked for too much at once earlier in the week, I could not tell what had broken. Small batches meant I could always say "that batch is good, the next one is not".

### 7. What was hard

- Keeping my own understanding in step with the code. When the AI writes thousands of lines a day, "it works" is not the same as "I understand it". The Bucket List is my anchor: it is the one part I can explain line by line.
- Scope. Every good idea added another screen. I had to leave things out, like password reset.
- Not letting a polished look hide a weak foundation. I spent the last two days on cleanup, one live-update service for the couple, and the audit, with no new features.

### 8. What I am proud of

Two accounts, two browsers, and a message, a mood and a reaction appearing on the other side without refreshing. It felt like the first week's pairing moment all over again, but now there is a whole shared space behind it. I am also proud that I got there by learning to work with AI properly, not by fighting it or letting it run.

## Overall

This week I learned to maximize AI, to embrace it, and to orchestrate it well. Embracing it meant I stopped treating AI as a shortcut I should feel guilty about and started treating it as a team I could lead: Claude Code as the lead, Codex as a second opinion and worker, each with a clear role. Maximizing it meant giving it what it needs to do its best work: written design rules, clear security rules, small batches, and a test after every batch. Orchestrating it meant that I decided what to build, in what order, and when something was wrong. The AI can generate quickly, but the vision, the privacy rules, the review and the "no, that is not right yet" were mine.

My plan for Week 4 is to finish the security fixes, record the demo video, and make sure I can explain every part of the project when I present it.
