---
title: "Recommended Resources"
date: 2023-01-18T21:39:20-05:00
draft: false
---

Here's a list of resources I enjoyed, with a few comments.

## Papers

- [Hoard: A Scalable Memory Allocator for Multithreaded Applications](https://www.cs.utexas.edu/users/mckinley/papers/asplos-2000.pdf): Hoard is a parallel memory allocator that avoids fragmentation and false sharing by hoarding memory from the single-threaded system memory allocators and giving it out in parallel for better performance.
- [The Emperor's Old Clothes](https://dl.acm.org/doi/pdf/10.1145/358549.358561): Hoare, of quicksort and ALGOL fame, explains why simplicitly is a virtue, and how a committee can destroy a language. He mentions how bounds checking was implemented in ALGOL, and composition allowed it to grow to become a simple yet powerful language.
- [Growing a Language](https://www.cs.virginia.edu/~evans/cs655/readings/steele.pdf): A paper about how to build a language to grow -- a language should be flexible, have a welcoming community, have generics and operator overloading, and worse is better.
- [Three Approaches to the Quantitative Definition of Information](http://alexander.shen.free.fr/library/Kolmogorov65_Three-Approaches-to-Information.pdf): This paper formulates what's now called Kolmogorov complexity, which states that the entropy of an object is determined by the smallest possible programming language that can express said information. This explains compression, signal processing, and many other things in CS in just 5 pages.
- [Technology and Courage](https://cseweb.ucsd.edu/~wgg/smli_ps-1.pdf): A paper by technology pioneer, Ivan Sutherland, who was on the team at MIT who built the first tablet. This paper goes into his high level thoughts about business, software, and life.
- [Reflections on Trusting Trust](https://www.cs.cmu.edu/~rdriley/487/papers/Thompson_1984_ReflectionsonTrustingTrust.pdf): A classic paper on how software isn't really trustable unless you examine both the tools to build it and the code itself. This paper was surprisngly prescient, given the security problems we have now with software.
- [Hazard Pointers: Safe Memory Reclamation for Lock-Free Objects](https://ieeexplore.ieee.org/document/1291819): It was thought for a long time that garbage collection was a prerequisite to fast concurrent data structures, due to the lack of efficient bookkeeping for when to free parts of a data structure correctly. This paper discusses hazard pointers, a way to mark parts of a data structure as freeable even without garbage collection.
- [A Lazy Concurrent List-Based Set Algorithm](https://people.csail.mit.edu/shanir/publications/Lazy_Concurrent.pdf): This paper details concurrent Skip Lists, which was implemented in the java collections library in Java 1.6.
- [Crash Only Software](http://www.usenix.org/events/hotos03/tech/full_papers/candea/candea.pdf): A paper on explaining why crash-only software is good, and a classification of such software.
- [Better bitmap performance with Roaring bitmaps](https://arxiv.org/pdf/1603.06549.pdf): Roaring bitmaps, a faster data structure and more storage efficient data structure for bitmaps, by using both run-length encoding and array packing.
- [RRB-Trees: Efficient Immutable Vectors](https://hypirion.com/pdf/RMTrees.pdf): RRB-Trees, the Relaxed Radix Balanced Tree, is a purely functional data structure that is an improved version of the HAMT, the Hash Array Mapped Trie, which is the vector data structure in Scala and Clojure.
- [Time Bounds for Selection](https://people.csail.mit.edu/rivest/pubs/BFPRT73.pdf): A paper that explains the `PICK` selection algorithm, which can select the ith smallest of n numbers in O(n) time. This algorithm is more commonly known as quickselect.
- [Quicksort](https://academic.oup.com/comjnl/article-pdf/5/1/10/1111445/050010.pdf): A paper that explains the classic quicksort algorithm, the first O(n log n) sorting algorithm that took sublinear memory.
- [End to End Arguments in System Design](https://web.mit.edu/Saltzer/www/publications/endtoend/endtoend.pdf): A paper on a design principle, the "End to End" argument, that explains why having functionality at the lower levels of a system may be redundant or useless compared to putting them at a higher level of a system.
- [Pattern Defeating Quicksort](https://arxiv.org/abs/2106.05123): A sorting algorithm for the Dutch National flag problem, which can solve it in O(nk) time. This is the current unstable sort algorithm in rust, with an ~5-10% better performance over the current rust stable sort, timsort.

## Links

- [Beej's Guide to Network Programming](https://beej.us/guide/bgnet/html/) Learn how to program network sockets in C.

## Courses

- [MIT Performance Engineering of Software Systems](https://ocw.mit.edu/courses/6-172-performance-engineering-of-software-systems-fall-2018/): A good course to learn more about computer architecture and what's going on under the hood when you execute code.
- [Design and Implementation of Programming Languages](https://www.cs.umd.edu/class/fall2022/cmsc430/index.html): A course that incrementally introduces compilers, by implementing a compiler that emits x86 assembly.
- [The Modern Algorithmic Toolbox](https://web.stanford.edu/class/cs168/index.html): A course that thoroughly explains useful algorithms and what they can be used for, with lots of real world examples.
- [Database Systems](https://15445.courses.cs.cmu.edu/fall2019/schedule.html): A course all about databases, explaining algorithms and data structures for indexes, storage, logging, locking, and concurrency protocols, like MVCC and 2PL.

## Books

- [ARM System Developer's Guide](https://www.amazon.com/ARM-System-Developers-Guide-Architecture/dp/1558608745): Details the ARM ISA. A bit dated at this point, but covers the fundamentals.
- [Algorithms and Data Structures for Massive Datasets](https://www.amazon.com/Algorithms-Data-Structures-Massive-Datasets/dp/1617298034): Algorithms and data structures that scale to meet the demands of large datasets.
- [Algorithms for Modern Hardware](https://en.algorithmica.org/hpc/): A great resource for learning about performance engineering.
- [Antifragile](https://www.amazon.com/Antifragile-Things-That-Disorder-Incerto/dp/0812979680): A sequel to the Black Swan, focusing on things that get stronger when put under stress, and how to build systems that do the same.
- [Behind Deep Blue](https://www.amazon.com/Behind-Deep-Blue-Building-Computer/dp/0691118183): A book about the team that built deep blue, the first computer to defeat the world chess champion.
- [Computational Geometry](https://www.amazon.com/Algorithms-Data-Structures-Massive-Datasets/dp/1617298034): a book that looks at algorithms geometrically. There's sections on calculating nearest neighbors, object collision, mapping algorithms, dimension reduction, graphs, and even querying a database. I didn't know computational geometry had so many applications!
- [Crafting Interpreters](https://craftinginterpreters.com/): Learn about compilers by implementing two interpreters for a full featured language named lox.
- [Database Internals: A Deep Dive](https://www.databass.dev/): A book that teaches databases in two parts: storage engines, and then as distributed databases.
- [Designing Data Driven Databases](https://www.amazon.com/Designing-Data-Intensive-Applications-Reliable-Maintainable/dp/1449373321): The best book for learning about distributed systems.
- [Game Programming Patterns](https://gameprogrammingpatterns.com/): A book about Design Patterns for game development. The examples are in C++, and focused on games, but can be applied to many domains outside of it.
- [High Performance MySQL](https://www.amazon.com/High-Performance-MySQL-Optimization-Replication/dp/1449314287): Learn about how to use and deploy MySQL, while squeezing as much performance as possible while dodging pitfalls.
- [Irrational Exuberance](http://www.irrationalexuberance.com/main.html?src=%2F): A book about economic bubbles and regression to the mean.
- [Kill it with Fire](https://www.amazon.com/Kill-Fire-Manage-Computer-Systems/dp/1718501188): explains how to maintain and extend legacy systems, with notes on leading teams and driving change.
- [Learn you a Haskell for Great Good!](http://learnyouahaskell.com/): An introduction to haskell, a statically and strongly typed functional programming language.
- [Learn you some Erlang for Great Good!](https://learnyousomeerlang.com/): An introductory book to Erlang/OTP, a functional programming language with lots of libraries suited for web programming.
- [Meditations](https://www.amazon.com/Kill-Fire-Manage-Computer-Systems/dp/1718501188): A classic book by Marcus Aurelius on the stoic philosophy, with gems that still ring true today.
- [Operating Systems, Three Easy Pieces](https://pages.cs.wisc.edu/~remzi/OSTEP/): A book that tackles teaching operating systems in three pieces: virtualization, concurrency, and persistence.
- [Probabilistic Data Structures and Algorithms for Big Data Applications](https://www.amazon.com/Probabilistic-Data-Structures-Algorithms-Applications/dp/3748190484): A book on probabilistic data structures that are useful for big data. The six chapters cover many data structures for each problem.
- [Programming Pearls](https://www.amazon.com/Programming-Pearls-2nd-Jon-Bentley/dp/0201657880): Algorithms and data structures that Jon Bentely, the creator of kd-trees explains in succint prose. There's a lot of great exercises and the author's storytelling makes the book an entertaining and fast read.
- [Proofs: A long form Mathematics Textbook](https://www.amazon.com/Designing-Data-Intensive-Applications-Reliable-Maintainable/dp/1449373321): An approachable book on proofs with lots of problems and stories. Proofs and being able to read mathematical notation are much more useful than I would've thought.
- [Purely Functional Data Structures](https://www.amazon.com/Purely-Functional-Data-Structures-Okasaki/dp/0521663504): A book on data structures for functional languages, like SML.
- [SQL Performance Explained](https://sql-performance-explained.com/): The book that made indexes click for me, with accompanying SQL code in many dialects of SQL, like SQL Server, Oracle, MySQL, and Postgres.
- [Seven Concurrency Models in Seven Weeks](https://www.amazon.com/Probabilistic-Data-Structures-Algorithms-Applications/dp/3748190484): concurrency models in many different languages, including java, clojure, and erlang, and how they differ, with quick explanations on the pros and cons of each.
- [Seven Databases in Seven Weeks](https://www.amazon.com/Probabilistic-Data-Structures-Algorithms-Applications/dp/3748190484): a whirlwind tour of some common NoSQL databases, like Redis, Neo4j, DynamoDB, and Hbase.
- [Systems Performance: Enterprise and the Cloud](https://www.brendangregg.com/blog/2020-07-15/systems-performance-2nd-edition.html): Learn how to profile and improve performance and observability of systems. A must have for anybody learning in a big tech company.
- [The Art of Multiprocessor Programming](https://www.amazon.com/Art-Multiprocessor-Programming-Revised-Reprint/dp/0123973376): A book that goes into great depth about concurrent programming, with thorough exercises.
- [The Black Swan](https://www.amazon.com/Black-Swan-Improbable-Robustness-Fragility/dp/081297381X): An options trader explains why outlier events are actually quite common and hard to hedge against. I picked this up for the nod to Popper, but stayed for the thoughts on the market.
- [The Innovator's Dilemma](https://www.amazon.com/Innovators-Dilemma-Revolutionary-Change-Business/dp/0062060244): How companies adjust (and don't adjust) to change, and how incumbents lose market share to new competitors.
- [The Linux Programming Interface](https://man7.org/tlpi/): a book on the linux OS, glibc, and system calls. Waiting for a second edition soemday to cover io_uring, cgroups, and other things.
- [The Little Book of Semaphores](https://www.amazon.com/Kill-Fire-Manage-Computer-Systems/dp/1718501188): A gentle introduction to mutual exclusion by introducing semaphores, the basis of almost all concurrent algorithms.

## Utilities

- [fish](https://fishshell.com/): A shell with completions and sane scripting
- [pagefind](https://github.com/CloudCannon/pagefind): Static search that works offline without needing to run a local server
- [pandoc](https://pandoc.org/): A universal document converter
- [pdf2txt](https://github.com/clulab/pdf2txt): Reading pdfs as plain text
- [ripgrep](https://github.com/BurntSushi/ripgrep): Grep but faster
- [scalene](https://github.com/plasma-umass/scalene): To diagnose python performance problems
- [termux](https://termux.dev/en/): Run a unix terminal on your android phone
- [panamax](https://github.com/panamax-rs/panamax): Mirror crates.io locally
