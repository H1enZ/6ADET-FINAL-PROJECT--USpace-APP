# Reflection

**Project:** USpace – A Private App for Couples  
**Live Demo:** https://h1enz.github.io/USpace/  
**Author:** Mikko Panergo, 6ADET

## What I Set Out to Do

When I first thought of creating USpace, I wanted to build something that would be meaningful to couples, especially those who are in long-distance relationships. I wanted to create a private space where two people could still feel connected even when they couldn't physically be together.

My idea wasn't just to create another messaging application. I wanted USpace to have its own personality and purpose. I imagined an application that would feel romantic, warm, interactive, and personal. A place where couples could save their memories, write love notes, plan future experiences, and express their feelings.

That's why I came up with features like the Timeline, Love Notes, Time Capsules, Bucket List, and Therabot. Each feature has its own purpose. For example, I wanted the Timeline to feel like a digital scrapbook, Love Notes to feel like personal letters, and Time Capsules to make special messages more exciting by allowing couples to open them at a future time. For Therabot, I wanted something that could provide comfort and guidance when couples were having misunderstandings or difficult days.

My main goal was to create something that couples could consider their own little space. I wanted USpace to be more than just an app they open to send messages. I wanted it to be a place where they could create memories, appreciate each other, and strengthen their relationship.

## My Role in the Project

Throughout the development of USpace, I took the role of project creator, AI orchestrator, and prompt engineer.

I was the one who came up with the concept, planned the features, decided how the application should look, and determined how I wanted users to feel while using it.

Since I used AI tools such as Claude Code and OpenAI Codex, a large part of my responsibility involved writing detailed prompts, giving instructions, reviewing the generated results, and making sure everything followed my original vision.

However, I learned that using AI doesn't automatically mean everything will turn out exactly how I imagined it. There were times when the AI generated something that worked technically but didn't match the design or experience I wanted. Because of that, I had to revise my instructions, explain what needed to change, and check the results again.

I was also involved in organizing assets, making design decisions, directing debugging, checking functionality, and deciding which changes to keep.

I want to be transparent that AI generated much of the application's source code. I don't want to claim that I personally wrote everything because that wouldn't be true. My main contribution was creating the vision, directing the development process, evaluating the output, and making the final decisions about the application.

This experience made me realize that working with AI still requires responsibility, critical thinking, and a clear understanding of what you're trying to accomplish.

## The Part I Wrote Myself

The feature I personally coded was the **Bucket List**.

I chose this feature because I wanted to experience writing Flutter code myself instead of relying entirely on AI. I wanted to understand how widgets work, how user interactions are handled, and how information is displayed and updated in the application.

The Bucket List allows couples to add activities they want to accomplish together, view their plans, mark activities as completed, and delete items when needed.

At first, I thought implementing these functions would be simple, but when I started coding, I realized that even a basic feature requires understanding several parts of the application.

During my first implementation, I encountered five bugs. It was frustrating because I expected the feature to work after writing the code, but some functions weren't behaving the way I wanted.

Instead of just replacing everything with AI-generated code, I tried to understand what was causing the problems. Through debugging, I learned more about Flutter widgets, `setState`, services, and how the database uses Row Level Security to control access to information.

What I appreciated most about this experience was that I actually learned from my mistakes. When I finally understood why something wasn't working, I felt more confident about what I had written.

The Bucket List may only be one part of USpace, but for me, it was one of the most important parts of the project because it showed me what I could learn by writing and fixing code myself.

## What I Learned

Developing USpace taught me lessons that go beyond just creating an application.

One of the biggest lessons I learned is that **AI can help me work faster, but it cannot replace my own decisions**.

There were times when AI followed my instructions exactly, even when those instructions were wrong. One example was when development went in the direction of a Flask application, which wasn't what I originally intended for USpace. Another example was when the splash screen technically worked but didn't match the design I had imagined.

Those experiences taught me that I shouldn't assume something is correct just because the AI successfully generated it or because the application runs without errors. I still need to evaluate whether it actually meets my goals.

I also learned how important clear instructions are. At first, I would repeatedly explain the same design preferences and development requirements. Eventually, I realized that documenting my design rules, mood rules, and Git guidelines made the development process more consistent.

Another important lesson was about security. Since USpace handles private conversations, memories, and personal information, I learned that security shouldn't depend only on what users can see on their screens.

For example, we discovered issues involving Time Capsules and real-time channels. These problems made me realize that even if a feature looks secure in the interface, the database and backend must enforce the same rules.

I also learned that making smaller changes is better than trying to improve everything at once. During development, I worked through ten focused redesign batches. Testing each batch helped me identify problems more easily and understand what changes were being made.

I realized that the order of development matters too. Database changes should be completed before implementing the features that depend on them. Otherwise, problems can occur because the application expects something that isn't available yet.

Lastly, I learned the importance of honesty when documenting my work. I believe there's nothing wrong with using AI as long as I'm transparent about how I used it and what I actually contributed.

This project helped me understand that being responsible for an application isn't just about making it look good or adding impressive features. It's also about understanding its limitations, acknowledging mistakes, and continuously improving it.

## My Observations About Working with AI

Looking back at my experience using Claude Code and OpenAI Codex, I noticed that the quality of the results depended heavily on how clearly I explained what I wanted.

Whenever I provided detailed instructions about the design, behavior, or purpose of a feature, the output was usually closer to my expectations. But when my instructions were too general, the results sometimes looked generic or didn't match the personality I wanted for USpace.

This made me realize that prompt engineering isn't simply telling AI to build something. I have to think carefully about the requirements, possible problems, and expected results before giving instructions.

I also noticed that I became more organized as the project progressed. I started establishing rules about the application's design, security, and Git workflow. These helped me maintain consistency instead of repeatedly correcting the same mistakes.

One of the things that stood out to me was how important it is to question AI-generated code. During our security review, we discovered that some restrictions were only being enforced through the interface rather than the database.

For example, a sealed Time Capsule still had a vulnerability involving its photo, and some real-time channels were not restricted properly. Those issues showed me that a feature can appear to work correctly while still having serious problems behind the scenes.

I also realized that my GitHub history and documentation could have been more organized. There were times when I created and deleted documentation files repeatedly because I was working under pressure and trying to finish several requirements.

If I had managed my documentation alongside the code changes from the beginning, my development history would have been easier to follow.

Another thing I noticed was that my understanding improved whenever I personally investigated a problem. This was especially true with the Bucket List because I was able to identify and fix issues in the feature I wrote.

Overall, working with AI taught me that I shouldn't just focus on how quickly I can finish something. I should also focus on whether I understand the results, whether the application is secure, and whether the final product actually reflects my intentions.

## What I Would Do Differently

If I were given the opportunity to start this project again, there are several things I would change about how I approached development.

First, I would spend more time reviewing my original proposal before starting the actual implementation. One of my mistakes was not being careful enough when making early decisions about the technology stack. This led to unnecessary work, including the Flask direction that didn't match my intended Flutter application.

Second, I would prepare my test accounts and testing environment much earlier. There were moments when I needed screenshots or wanted to demonstrate certain features, but I hadn't prepared everything beforehand.

I would also be more consistent with documenting my progress. Instead of writing or updating some journal entries afterward, I would record what I accomplished, the challenges I encountered, and the lessons I learned every week.

Another thing I would change is how I manage database updates. I learned that migrations should always come before the code that depends on them. If I followed that order consistently, I could have avoided some unnecessary debugging.

I would also make more time for testing rather than focusing too much on adding new features. There were times when I was excited to make USpace look better or introduce new functionality, but I realized that making sure existing features work properly is just as important.

Most importantly, I would spend more time understanding the source code instead of focusing mainly on directing AI to produce the application.

Although AI helped me turn my ideas into something functional, I realized that I still need to develop my own technical skills.

If I were to do this project again, I would challenge myself to write more features independently from the beginning.

## What I Would Do Next

If I had more time to continue developing USpace, I would definitely want to improve it and eventually make it available for real couples to use.

I don't want USpace to remain just a final project that I submitted for a grade. Since I was the one who came up with the concept, I feel personally connected to it, and I want to see how far I can develop the idea.

One of the first things I would do is test the application with real couples, especially those in long-distance relationships. I want to know whether the features are actually useful and whether the application helps them feel more connected.

I would also improve the animations, transitions, and overall user experience. From the beginning, I wanted USpace to feel warm, romantic, and personal. I want users to feel like they're entering a space made specifically for them and their partner instead of just opening another ordinary application.

Another priority would be improving the security and reliability of the application. Since users would be sharing personal conversations, pictures, and memories, I want to make sure their information is protected. I would continue addressing the remaining security audit findings, testing partner synchronization, and improving the application's performance.

I would also work on features like real-time messaging, notifications, and the emotional support system to make them more reliable and helpful.

But most importantly, **I want to challenge myself to become a better programmer**.

I know that I relied heavily on AI throughout this project. While I was responsible for creating the concept and directing its development, I also understand that there's a big difference between asking AI to generate code and being able to write and explain that code myself.

That's why I want to continue practicing Flutter and Dart. My next personal goal would be to implement another feature by myself, perhaps Love Notes or part of the chat system, so I can gain more confidence in programming.

I would still use AI because I believe it's a powerful tool, especially when learning and solving problems. However, I want to become someone who uses AI because it makes my work more efficient, not because I cannot do the work without it.

For me, USpace isn't just an application I created. It's also something that shows how much I still have to learn and how much I can improve.

## Final Reflection

Looking back at the entire development process, I can say that creating USpace was both exciting and challenging.

There were moments when I felt proud because I could finally see the application I had imagined becoming real. There were also moments when I felt frustrated because something wasn't working, the design didn't match my expectations, or I had to repeat a process several times.

But despite those challenges, I learned a lot about project planning, application development, AI orchestration, prompt engineering, debugging, security, and decision-making.

What made this project meaningful to me was that it started with my own idea. I wanted to create something that could help couples feel appreciated, remembered, and connected, even when they were far away from each other.

Seeing that idea turn into an actual application was a rewarding experience.

I'm proud of what I accomplished, but I also recognize that I still have a lot to improve, especially when it comes to writing and understanding code independently.

I don't consider USpace a perfect application, and I know there are still issues that need to be addressed. However, I see those imperfections as opportunities to learn.

**My role in this project was to create the vision, direct the development, evaluate the results, and personally implement the Bucket List feature.**

If there's one thing I'll take away from this experience, it's that **AI can help me build what I imagine, but it's still my responsibility to understand what I'm building, question the results, and keep learning along the way.**

For me, that's the most important lesson I gained from creating USpace.
