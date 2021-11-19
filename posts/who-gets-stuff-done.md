---
title: "Who Gets Stuff Done"
date: 2020-03-12T11:52:45-05:00
draft: false
---

Software developers are generalists. Ask the average software developer questions about networking, databases, compilers, operating systems, data structures, distributed systems, and 9 out of 10 will tell you that they know something about them. But this generalist mentality begins to break down once you acknowledge one of the most fundamental things rules of life:

1. Nobody can be an expert at everything.

And if nobody can be an expert at everything, we eventually must have roles for our field. One mechanic alone cannot create a high performing and standards compliant car these days. It's just too hard. Likewise, software development is too hard for any one person to keep the whole field in their head. And that's a good thing. It means that we have roles for who does what, and that helps teams move quickly, without getting bogged down in the minutae.

So we have well defined roles for the work that we do on our teams, like Front-End developer, Back-End developer, DevOps, SysAdmin, Designer, Product Manager. All is dandy in the world. Well, all would be dandy if there wasn't a question of what makes an developer a developer.

Once a field becomes sufficiently mature, the practioners of the craft, (the real intense ones anyway) start sharing a common idea of the ideal practioner. First this starts out as vague and easy to achieve ideals, like "a real developer would be able to answer fizzbuzz in 30 seconds", or "a developer should be able to understand one programming language well", which is all hunky dory. And soon, a regulatory body of practioners, filled with the people who subscribe to that ideal the best is borne, and they create norms and disseminate them to the rest of the practicing population. Psychologists in America have the APA, doctors to pass a board certification, and lawyers have to pass the bar in each state. I'll call the idea of the ideal practioner the "soul" of the field, and the regulatory body (a la APA, bar, or other) the "body". If all is in harmony, the "body" and "soul" are in alignment -- the practioners agree with the higher ups on what should be taught, and what constitutes a "real" practioner.

The system I've described above works great when "body" and "soul" are in tune -- there is buy-in from both sides of the table. But programming has never had that. And it's because the field is too varied, one that should've been split up (and probably will be) in the coming decades. You see, development doesn't fit so neatly like other professions do in this model, because at large, there aren't two groups of programmers. There are three. Academics, Systems Programmers, and Application Programmers.

In computer science, academics do research on problems that are remarkably forward thinking -- as you read this, papers are being published for increasing the speed of low-level hardware, operating system calls, database reads and writes, distributed systems, programming langauges, AI, statistics, quantum computing, cryptography, what have you. These all have wide impact, maybe even decades later -- Barbara Liskov (of the Liskov substitution principle) was working on object oriented languages in the 60s, some 30 years before they made it to the mainstream for practioners in the form of java. Liskov as well as Lampert made long lasting contributions to distributed systems research, which has changed the way practioners have built their infrastructure, and has allowed companies like google and amazon to become global companies. RSA encryption, made in the 70s, is widely used today. There is a long tail of important and groundbreaking research, but you get the gist -- Academics do important research.

Systems Programmers are the ones who, when they see a reason to, implement the academic's work. Linux implements some of the cutting edge of operating systems research. Zookeeper implements the consensus algorithms that academics envisioned from the 70s. OpenSSL implements RSA encryption, and many others. System programmers transfer the abstract, theoretical world of theorems and proofs into libraries and packages for the rest of us to use.

Application programmers are the ones who take the work of System Programmers and create products and applications that are used by the world at large (read: not tech-savvy people). They deal with the nitty gritty of presentation and User Experience, and find creative ways to use the tools they have to make products that require very little in-depth knowledge of the product to use.

With these three camps, it is impossible to have either a "soul" or "body" for programmers. I'll list out the ideal "body" and "soul" for each of the three camps.

Academics:

- Body:
  - An academic body that tests developers on the rigor of their proofs and theoretical knowledge.
- Soul:
  - A practioner that thinks from first-principles to expand the rigor and breadth of the field.
- Education:
  - A higher education (Masters or PhD)

Systems Programmers:

- Body:
  - A coalition of workers who stress low-level (in code) fundamentals, and tool building for performance.
- Soul:
  - A practioner who doesn't necessarily need to produce academic research, but can pick up academic works and translate them to libraries and packages.
- Education:
  - A degree in the field (Undergrad, Masters, or PhD)

Application Programmers:

- Body:
  - A group of programmers who build products for the general population.
- Soul:
  - A practioner who can pick up a wide variety of tools, and knows how to use them to quickly create the required product.
- Education:
  - Varied.

All three groups are in constant conflict, and this leads to the chaotic state of software development -- at one end, the Academics aren't even implementing software -- and at the other end, Application programmers stress a high-level knowledge of a variety of areas. Agreement isn't necessary in this case, but it is something that would benefit largely in one area. Interviews.

## The Hiring Bar

After being interviewed for days by Bell Labs, a young up-start computer scientist named Bjarne Stroustrup found a job at one of the most coveted research labs in the nation.

After being interviewed for weeks by an Unnamed Big Firm, a young up-start new graduate named \${GENERIC_NAME} found a job at one of the most coveted firms in the nation.

See any relation? You should, because I made it painfully obvious. Big firms subject prospective candidates to a brutal interview loop, constituting of knowledge of low-level operating systems, compiler theory, algorithms and data structures, distributed system design, and others. This all makes sense if you want a software developer who will work on all of these areas, but most firms do not actually need their candidates to know this knowledge on the job -- it is abstracted away from them by the work of Systems Programmers who provide (mainly) good libraries to base work off of. Maybe Untitled Big Firm has does have problems of scale -- but your average start-up does not. And yet, the hiring process continues this way.

The big firms might be justified for want of unicorn talent (after all, they're willing to pay for it), but most firms simply cannot afford to pay the compensation that these developers are worth these days. And yet, the hiring process continues, and I hear companies complain on LinkedIn about how hard it is to hire and retain good developer talent. To those companies, I only have a few choice words: buck the norms, and fix your interview process.

I've heard countless stories of acquaintances not passing an interview because they were asked questions that were outside of their specialization, which matched the job. One acquaintance with an interest in robotics and hardware was asked about implementing a Todo CRUD app. He failed. Another friend was asked about low-level disk write system calls for a React position.

I think this happens because companies have a mistaken perspective of "who gets stuff done", A.K.A "10x engineers". They assume that to be a "great" developer, you must understand everything about your computer, and that translates to great code. That is not true. A good developer knows the appropriate level of abstraction for the task at hand. Asking a systems programmer about application programming, or vice-versa, is a surefire way to destroy your hiring pipeline. The best companies know this, so they don't do that. They hire "1x" engineers, and make it to market "10x" as fast as the other firms. Those firms win. The product people love the devs because they crank out bug-free code in record time, and the customers love those companies because they make genuinely good products.

Always value getting stuff done.
