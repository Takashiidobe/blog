---
title: "Software that lasts Offline"
date: 2021-10-01T23:05:13-05:00
draft: false 
---

It seems like every day software gets outdated. It's so hard to build software that lasts for 3 years, let alone 30. Yet the houses we live in have seen much longer lives, with just a bit of refurbishing here and there. Why can't our software be the same way? \_why the lucky stiff said something that resounds with me as a programmer as he left the internet.

> To Program anymore was pointless. 
>
> My programs would never live as long as the trial.
>
> A computer will never live as long as the trial.
>
> What if Amerika was only written for 32-bit power pc?
>
> Can an unfinished program be reconstructed??
>
> Can I write a program and go, "Ah, Well, You get the gist of it."
>

Our software doesn't last as long as the written word. It's a very defeating thing to think that most of our code doesn't last that long. I wondered if it had to be this way, or if it was something to do with how we approached software writing. C code has lasted for a few decades, and could last a few more -- there's lots of COBOL and FORTRAN code in the wild that's 50 years old. Software that lasts is both high-level and low-level at the same time -- assembly would never last because it's tied to its platform.

A higher-level language need not be tied to any specific architecture. Yet the need for compatibility with architectures, past, present, and future makes it so the language must only build off of low-level primitives. A contradiction. 

I want a language that has offline documentation, that is robust, has wide compatibility in the past, present, and future, has standards, has multiple implementations, is fast, and is easy to develop for. Here's a short list of the languages I looked at, with some pros and cons for each in making software that lasts.

## Javascript

Javascript is well specified (by committee), with multiple implementations, and a strong commitment to backwards compatibility -- but that's about where the pros end. Even though I coded professionally in Javascript for a few years, things about the language still trip me up -- I sometimes forget to check for nulls, or I get different types than what I'm expecting when I use the standard library. As well, I know those things will never be fixed, because the web is the most popular for programming. Therefore, fundamentally, the language will never be able to smooth out its warts.

## Typescript

Typescript smooths out *most* of the usability issues of Javascript, and gives it static typing, generics, and new constructs (enums, interfaces, types). It compiles to Javascript quickly, and considering how accessible Javascript is, it shares most of its accessibility pros. That being said, Typescript has more lax backwards compatibility requirements, but with its compatibility to Javascript, won't be able to fix the language's warts. 

## WASM

Web Assembly is a new contender for web language of the future *TM*. It's a minimalistic language with S-expressions (like lisps) and is meant to be an easy compiler target. Go, C, C++, Rust, and others can compile down to it, targeting the WASM capabilities of the browser. As well, WASI seems like a portable way to run sandboxed applications in the future.

It's too low-level for productive use, but is an interesting foray into fixing the kludge of the web.

## Ruby

Ruby is the most OOP language I can think of -- message passing, everything is an object, and GC pauses ad nauseum. It's a language with a lot of expressiveness, and a lot of elegance. It has strong C bindings, so it has good interop with system libraries -- and pretty good backwards compatibility.

That being said, it's slow and clunky to write. The philosophy of expressiveness means that everybody writes ruby code differently, and there's a huge divide between ruby programmers, who are more restrictive with what functionality they use, and rails programmers, who are more keen on monkey-patching everything they can find for usability reasons. Not to say one side is right, but the language's stewardship has been on appeasing many camps, and that leads to fragmentation. 

## Python

Python is also very OOP, but contrary to ruby, it even comes with its own Zen, which you can read by entering `import this` at the REPL.

Beautiful is better than ugly.
Explicit is better than implicit.
Simple is better than complex.
Complex is better than complicated.
Flat is better than nested.
Sparse is better than dense.
Readability counts.
There should be one-- and preferably only one --obvious way to do it.

Python prefers fewer ways to do one thing, but that zen has been wearing off, with a huge standard library, which makes it hard to commit to backwards compatibility. Python has some system dependencies that are less than stellar when it comes to backwards compatibility, and the large surface area can make it hard for the language to keep stable.

Oh yeah, and remember Python3?

## OCaml

OCaml is an interesting language; it has a bytecode interpreter, cross compilation, and compilation to native, just like Haskell. It's relatively fast to compile, but has issues with backwards compatibility and footguns. As well, the standard library has been reimplemented by many, including by Jane Street, twice (Base and Core). 

It's a clear language with some baggage (Few people use the "Object Oriented" or "O" features of "OCaml"). For loops and classes are often struck down in code review as anti-patterns. Best to be functional, all the time.

It is relatively fast, with a good ecosystem (Dune makes building OCaml apps pretty nice in 2021) but it's still a relatively small ecosystem, fighting against Haskell to become Typed Functional Programming's main language.

Offline Documentation is great, and the standard library has few wants of its environment, but it lacks multicore support -- in an increasingly parallel world, that's a deal-breaker. It's looking like a reimplementation of the standard library with async might require a major version bump, to (5.X). 

## JVM languages (Java, Scala, Clojure)

JVM languages are pretty strong, with the JVM allowing users to target many platforms with their code (since the JVM runs on many things). That being said, the JVM offers some penalty, because the runtimes can be quite hefty and difficult to port. It's not quite as easy as sending someone a binary and they can run it, or easy to containerize JVM apps, unlike those that offer native binaries.

## CLR languages (C#, F#)

Same as the JVM languages, although I have to say that F# and C# are pretty fun to program in.

## Go 

Go was the first *serious* language in the list I considered learning -- simple like C, with a strong standard library for the modern era with a focus on async + web programming.  Sounds like a dream. Oh, and fast compile times and cross-compilation. Woah. Relatively small native binaries that don't rely on libc? Doable in Go.

Lots of big projects have been done in go, like most hashicorp stuff, docker, kubernetes, and a wealth of devops/cloud tools. It's a productive language, and one that nudges you to sane defaults.

But it's not all sunshine and roses -- the package managing story has been a nightmare, there are no generics (Hello casting to Interface{}) and I don't understand why a GC'ed language should have pointers and references explicitly? You get a lot for free, just by using Go, but you pay for it with complexity -- I rarely miss generics as an application developer, until I'm slapped with complexity because the library developer decided to hand over the complexity to me. Go also has one standard implementation and stewardship led by Google, which makes it a bit odd -- Google has never been one for backwards compatibility, and it seems like Go might be due for a Go 2.0, which could be an ecosystem and binary break for Go. Only time will tell if Go can survive the blow, or if it'll go with the route of holding onto the choices of the past.

## C++

C++ is the first language on this list with no Garbage Collection, it has a specification that's ISO standardized, with many committees, and with many implementations. It has functionality for OOP, Functional Programming, Generics, async, with the promise of being as fast as C while staying easier to use.

It mostly capitalizes on that promise. With the advent of modern C++, even though C++ has added many features, it has had a strong promise towards backwards compatibility (it keeps ABI compatibility for a long time, only recently breaking ABI in C++11), and only removing clearly broken functionality (auto\_ptr, anyone?) But it can be hard to use -- (the iterator API is one frustrating example), and it can be hard to see the runtime cost of the abstractions you use -- Even though C++ follows the "Zero-Cost Abstractions" principle, where you don't pay for what you don't use, and what you do use you couldn't hand-code any better, it breaks down somewhat -- `std::map` is extremely slow on certain workloads, because it's just implemented incorrectly -- and Iterators are a good example of an API footgun (remember to always check for `.end()`!). 

The complexity is never really ever paid off -- you have to litter your code with extra keywords like const to the left and right of your functions, along with noexcept, and final, and override. You have to remember what is and what isn't virtual, and use keywords accordingly, and you have to always generate move constructors, copy constructors, and remember which one is which -- why are there so many ways to initialize an object, and why are there so many things to remember when you write your own class?

Oh, and what's the difference between struct and class? Who knows?

C++ is a language with lots of promises but it has run into the limits of its promises -- backwards compatibility, ease of use, performance, and expressiveness are all in tension, and C++ is the language you can see that in the most.

## C 

Meanwhile, C is much more minimalistic than C++. You get nothing -- no expanding arrays, no hashmaps, no trees, no graphs, no async, no unicode, nothing.

It's a very bare language. That helps it with portability (C is the most portable language on this list by far) but it pays that price by doing almost nothing for you.

It's a high-level language that makes few choices for you and leaves you in a sandbox of your own creation. That can make code-sharing hard, since it's bound to its environment -- if you want to make a cross platform library, you have to be careful about which libraries you use, since different OSes have different system libraries.

It has a static type system and is speedy, for sure -- but it can be clunky and unsafe as well.

## Rust Every Day (For 3 years)

With all that being said, I've decided to pick Rust as my language of choice for the next 3 years for as many programming related tasks as I can. Rust is pleasant to develop for, has pledged backwards compatibility since 2015, targets a wide variety of architectures (thanks mainly to LLVM) and I'm convinced is a language for the rest of my career; it has a great team working on it, with a unique governance structure that makes it resilient to being steered by one interest group.

It's taken some great ideas from functional programming (Tagged Unions, Sum Types, iterators) while keeping the runtime promises of more imperative languages. It's a great language to learn for the future, and one that I'm sure will keep on growing, and for that, I'm throwing my weight behind it.

Rust every day. For 3 years. Then I'll revisit this and see what's changed, but I'd like to use Rust for the next 10 years, at least.

