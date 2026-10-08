# Reflection

**Project:** USpace, a private app for two people in one relationship
**Live demo:** https://h1enz.github.io/USpace/
**Author:** Mikko Panergo, 6ADET

## What I set out to do

I wanted a private space for couples, including long-distance ones, that feels romantic, warm and polished and that keeps what two people share actually private. I did not want a chat app with extras. I wanted a place with its own personality: a scrapbook Timeline, letter-like Love Notes, ceremonial Time Capsules, a calm Therabot.

## My role

I was the project creator, AI orchestrator and prompt engineer. I came up with the concept, decided how it should look, work and feel, planned the features, wrote the prompts, coordinated Claude Code and OpenAI Codex, reviewed what they produced, organised and fixed assets, directed debugging, and made the final decisions.

Although AI generated much of the source code, I was responsible for directing it and for deciding what the product became. Providing prompts and reviewing generated code is different from personally writing source code, and I say so openly in [AI-USAGE.md](../AI-USAGE.md).

## The part I wrote myself

The Bucket List is the feature I coded by hand. I chose it because I wanted to understand how Flutter handles user interaction, state, and displaying and updating stored data. Adding, showing, ticking and deleting items made widgets, `setState`, services and row-level security click for me. Its first version had five bugs, and finding them taught me more than the happy path did.

## What I learned

- **AI accelerates; it does not decide.** It built exactly what I said, even when I was wrong (the Flask app), and it ran without errors on screens that did not match my design (the splash). Someone has to know what "right" is.
- **Rules beat repeated instructions.** Writing my design rules, mood rules and Git rules down once made every later session more consistent.
- **Security belongs in the database.** Time Capsules and Therabot only make sense if the rule holds even when a screen has a bug.
- **Small batches.** Ten focused redesign batches, each tested, were easier to trust than one big change.
- **Order matters.** Database migration first, then the code that needs it.
- **Honesty is part of the work.** The security audit, the commit-email note in the checklist and this document all say what is not perfect.

## Observations from the AI assistant

*Added by Claude Code, the AI assistant that worked on this project, after reading the repository and its history. These are my observations, not Mikko's.*

- The strongest pattern in the history is that the project's quality rose when its constraints were written down: the design system, the mood rules, the "stop and explain before touching security" rule. Where constraints were vague, the output was generic.
- Every serious defect found in this project was a place where a rule lived in the interface instead of the database: a sealed capsule whose photo could still change, and realtime channels anyone could join. The fixes moved the rule to the server. That is a good instinct to keep.
- The Bucket List is the clearest evidence of understanding in the repository, because its bugs were found, explained and fixed by the author. A useful next step is to trace one other feature, for example how a chat message goes from the text field to the partner's screen through `couple_sync.dart`, and explain it in the same way.
- Several commits are named "Create DOCUMENTATION" and "Delete docs/DOCUMENTATION" in a row, which shows documentation was done through the GitHub website under pressure. Keeping docs in the same commits as the features they describe would make the history easier to trust.
- Remaining work that matters most: apply the audit's medium-severity fixes to production in stages, add sample content to the test couple, and record the demo.

## What I would do differently

I would reread my proposal before answering the first question about the stack. I would create the test accounts before taking any screenshots. I would write the journal each week instead of afterwards. And I would put each database migration before the code that depends on it, every time.

**My role was to create the vision, direct the development, evaluate the results, and personally implement the Bucket List feature.**
