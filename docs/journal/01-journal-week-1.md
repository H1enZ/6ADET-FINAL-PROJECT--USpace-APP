# Project Journal

## Week 1 (September 16, 2026 to September 23, 2026)

This week was challenging but meaningful. I ran into problems with the tech stack, Git, deployment, design, privacy, and how much I relied on AI. Some of them were frustrating at the time, but each one taught me something about what it really takes to build and ship an app.

### 1. Starting over from Flask

The first version of USpace was a Python/Flask app, and it had to be thrown out. The reason was my own answer: when I was asked which stack to use, I chose "Python backend + frontend", even though my own proposal already said Flutter and Supabase. The Flask app could never have worked for this course, because GitHub Pages only hosts static files and cannot run a Python server.

I answered quickly without opening my own proposal or my repo first.

It was frustrating to see that work thrown away, even though it did not take long to build. The lesson is simple: before writing any code, I should reread my own proposal and the course template, and check where the project will be deployed. Those three things decide the stack, not what I feel like using that day.

### 2. Learning Git through problems

Git gave me the most errors this week. My files ended up in one flat folder, so Flutter could not find anything. I got `fatal: not a git repository` because my terminal was in `C:\USPACE APP` instead of the repo folder inside it. Then files I had never touched, like `LICENSE`, showed up as modified.

Working through these, I started to understand what Git expects. A repository is one specific folder with a hidden `.git` inside it, and commands only work from there. The "modified" files were only Windows line endings, so I used `git restore` to put them back instead of committing fake changes to my history. Before this week I thought of Git as a place to upload code. Now I see it as a record of changes, and I care about keeping that record clean.

### 3. The live link and Supabase settings

When I first opened my live link, it said "This build has no Supabase settings." The build itself had worked, but the deployed app did not have the values it needs to reach my database, because I had not added them as repository secrets yet. After I added `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` and rebuilt, it still showed the old message until I opened a private window, because my browser had cached the old version.

This taught me that an app gets its configuration from where it runs, not only from the code. It also corrected something I had wrong: the publishable key is not actually secret. It ships inside the app, and it is safe because the database's row-level security decides who can see what. The one that must never be public is the secret key, because it bypasses all of those rules.

### 4. Pairing two accounts

The best moment of the week was pairing two accounts on the live app for the first time. One browser started a space and got an invite code, the other joined with it, and after pulling down on Home both names appeared.

Seeing it work at a real web address made the project feel real. Every part had to work together for that one moment: sign-in, the database function that checks the code, the security rules, and the Home screen. I felt relieved and excited, and it gave me confidence that this is becoming something another person could actually use.

### 5. Privacy and screenshots

My first screenshots showed real full names and someone else's real email address, and they were about to go into a public repository. I had only been thinking about whether they looked good and showed the features clearly.

Once it was pointed out, it was obvious. Anyone on the internet could have seen that person's email, and it was not mine to publish. I retook the screenshots with invented test accounts. Next time I will create the test accounts before taking any screenshots, instead of fixing it afterwards.

### 6. Checking the AI's work against my design

The splash screen went wrong twice. First, it only flashed for less than a second and looked almost the same as the sign-in screen, so it seemed like there was no splash at all. It also did not match my mockup, which has a wax seal, a tagline and loading dots. After it was rebuilt, everything on it was stuck to the left instead of centred.

I caught both problems by looking at my live app next to my own mockup. That showed me that AI-generated code can run without errors and still be wrong. The code does not know what my design looks like; I do. From now on I check every screen against my mockup before I call it done.

### 7. How much of this was AI

Almost all of this week's code was written by AI: the database, the theme, the widgets and every screen. It made me much faster, especially when I hit errors I did not understand. But I also noticed that when something broke, I often could not explain why without asking.

I do not want to hand in a project I cannot explain. So I have decided to write the Bucket List screen myself. It is the simplest feature, the database table for it already exists, and I can use `couple_service.dart` as a pattern to learn from. I also want to get better at reading the code I already have, so I can find problems myself instead of only pasting errors.

## Overall

The biggest lesson this week is that a working app is more than working code. Where it is deployed, how it gets its settings, what goes into a public repository, and whether it matches the design all matter just as much. AI helped with a lot of it, but I was the one who had to notice when the result was wrong. Next week I want to understand more of what I build, starting with the one feature I will write myself.
