# Demo video

**Live app:** https://h1enz.github.io/USpace/
**Video:** *to be added: file `demo.mp4` in this folder, or a hosted link*
**Length:** aim for 3 to 5 minutes
**Recorded on:** a desktop browser, with the app in its 390 x 844 phone frame

## The demo couple

The video uses the two tester accounts from the [README](../README.md#tester-accounts), already paired as one couple on the live app. They hold invented data only: made-up names, pictures drawn for this project (sunsets, a beach, a city skyline, flowers) and sample text. No real people, faces or messages appear.

What is already in the demo couple (added on 8 October 2026):

- **Timeline:** six memories with one or two photos each, a place and a tag, customized with Film, Postcard and Taped frames and a yellow sticky note ("Best year so far").
- **Moods:** both partners have picked Loved today, so Home shows the merged "Loved together" state. Pick a different mood on one side to show the separate state.
- **Chat:** a short two-sided conversation about a cozy night on Wednesday.
- **Love Notes:** one note in the "Missing You" category with a flower photo.
- **Time Capsule:** one sealed capsule from Tester A to Tester B, opening on 8 October 2027, so it will not open during the recording. Write a new one to show the full flow.
- **Therabot:** one finished Couple Reflection, with each side answered privately and a shared reflection built only from short summaries.
- **Bucket List:** one goal, "See the cherry blossoms together" in Kyoto, with a budget of 60,000 pesos and 15,000 logged as savings.

Open two browsers (or one normal and one private window), one signed in as each tester, so both sides of a feature can be shown.

## What it shows

A suggested running order, so a viewer can skip to what they need. Timings are a plan, to be checked against the final recording.

| Time | Screen | What to do and say |
|---|---|---|
| 0:00 | Intro | What USpace is and who it is for: a private space for two people, including long-distance couples. |
| 0:20 | Sign in and pair | Sign in as Tester A. Show the pairing screen and the invite code that joins two accounts into one couple. |
| 0:50 | Home and moods | Pick a mood as Tester A. Switch to Tester B and pick a different one: they show separately. Pick the same mood: they merge into one shared state. Add a note. |
| 1:30 | Chat | Send a message and a reaction in one browser; it appears in the other without refreshing. |
| 2:00 | Timeline | The scrapbook corkboard: Polaroids, tape, up to 10 photos per memory. Tap the pencil to edit the board and move memories around. Add a memory with photos, a story, a place and a tag. |
| 2:50 | Love Notes | Write a note in a category and read it as a paper letter from the other account. |
| 3:20 | Time Capsules | Write and seal a capsule with a photo and an unlock date. Show that it stays hidden from both partners until then. |
| 3:50 | Therabot | Show Private Talk (nothing goes to the partner) and Reflect together. Answer a question as each tester. |
| 4:20 | Bucket List | The feature I wrote myself: add a goal with a place and a budget, log savings, tick it done. |
| 4:45 | Close | The privacy rules: only the two partners see anything, enforced in the database. |

Cover, in this order: the main user journey end to end, anything that only works in the live app (two people, two browsers), and the thing I am proudest of.

## Getting it into the repo

GitHub **blocks any file over 100 MB** and warns over 50 MB, so compress before
committing:

```bash
ffmpeg -i raw.mp4 -vcodec libx264 -crf 28 -preset slow \
       -vf scale=-2:720 -acodec aac -b:a 96k demo.mp4
```

Raise `-crf` (28 to 32) or drop to `-2:480` if it is still too large. If it still
does not fit, attach it to a **GitHub Release** or upload it unlisted and link it
here. Never commit the raw capture: git keeps it forever even after you delete
it.

## Before you record

- Real data off the screen: no classmates' names, numbers, faces or messages.
- Notifications off.
- Use the tester accounts and the sample data above, not "asdf".
- One unbroken take per feature. Say what you are doing while you do it.
- Clear the browser cache (Ctrl + Shift + R) so the latest version of the live app loads.
