# Project Journal

## Week 2 (September 23, 2026 to September 27, 2026)

*Written on 8 October 2026 from my notes and git history, because I did not fill it in during the week.*

Week 2 was the week USpace became an app with real content in it. Week 1 gave me sign-in and a countdown; this week it got memories, a bucket list, profiles and a theme switch. It was also the week I wrote my first real Flutter feature myself. It was slower and more stressful than Week 1, but I understood more of what I was building, and that made it the first week I felt like a developer and not only someone giving instructions.

### 1. The Timeline: the first feature that belongs to both of us

Before the Bucket List I built the Timeline with the AI: a memory with a photo, a caption and a date, stored in the private photo bucket, with a year filter, a detail page, and delete for the author only. The part I thought about most was the favourite button. A memory belongs to the person who added it, so the other partner must not be able to edit it, but either of them should be able to favourite it. Doing that in the screen would have been easy and wrong. It had to be a database function (migration 002), so the rule holds even if someone tampers with the app.

This was when I started to see why my privacy rules live in the database. A button I hide in the UI is only a suggestion. A rule in the database is a promise.

### 2. Writing the Bucket List myself

I started the Bucket List on my own: the model, the service, and a screen with To do / Done / All filters, ticking an item, and swipe to delete. I used `couple_service.dart` as a pattern. It was slower than asking the AI, and I got stuck more, but it was the first time I could explain every line.

My first version had five bugs. The worst was a Save button that could never be tapped, because the condition that enabled it could never become true. Another was a text controller disposed while its dialog was still closing, which crashes. They were found in review, and fixing them taught me more than the happy path did.

### 3. Savings without moving money

I extended the Bucket List with a location, a budget and a shared savings log with a progress bar and "how much to save each month". I decided early that the app records savings but never holds money: holding or moving money would need a licensed payment provider, and that is far outside this project. The savings stay in the couple's own bank or e-wallet account.

### 4. Pushing before migrating

The Bucket List showed "Could not find the table 'public.bucket_contributions'". I had pushed the code before running the database migration. The order matters: the database change has to land first, or the live app breaks. Profile photos failed the same way ("Bucket not found") because the last part of a migration had not run.

### 5. The security checklist found real things

Filling in the security checklist felt like homework, but it found three things: GitHub Actions pinned to moveable tags, photo size and type limits that only existed in the app, and my personal Gmail in old commits. I pinned the actions to commit SHAs, added the limits in the database, and switched to my GitHub no-reply email for new commits. I did not rewrite the old commits because that would break the links in my AI-USAGE file. I wrote that down honestly. I also grew the database security tests from 33 to 61, and all of them pass. I trust a rule more when I have tried to break it.

### 6. Profiles, birthdays and a theme switch

I added a profile photo, an editable name and a birthday, with birthday countdowns for both partners on Profile and Home. Profile photos got their own private bucket where each person can only upload into their own folder, while the couple can see each other's. I also added a Light / Dark / System theme switch. I decided the theme stays on the device and is not saved in the database, because it is a personal preference, not something the couple shares.

These were small features, but each one made me ask "who is allowed to see this, and who is allowed to change it?" before writing any code. By the end of the week I was asking that without being reminded.

### 7. Small Git lessons

Pushes were rejected several times because GitHub had newer commits, and `git pull --rebase` fixed it. Creating a folder on the GitHub website and another on my PC gave two folders that differ only by capital letters, which Windows treats as one. Now I create files only from my PC.

## Overall

Week 2 showed me that a feature is not finished when the screen works: the database, the migration order, the security rules and the documentation are all part of it. Writing the Bucket List by hand made me more careful about reading the AI's code too.

What I will do differently next week: run the migration before I push the code that needs it, create files only from my PC, and write the journal as I go instead of reconstructing it from git history.
