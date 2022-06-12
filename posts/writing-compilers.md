---
title: "Writing Compilers"
date: 2022-01-10T17:48:22-05:00
draft: false
---

In his post "Rich Programmer Food", Steve Yegge explains why you should
learn compilers:

> If you don't know how compilers work, then you don't know how computers work. If you're not 100% sure whether you know how compilers work, then you don't know how they work.

Throughout this post, Steve has some witticisms and some harsh
realizations:

> If you don't take compilers then you run the risk of forever being on the programmer B-list: the kind of eager young architect who becomes a saturnine old architect who spends a career building large systems and being damned proud of it.

While I wouldn't say the article **wholly** convinced me to learn about
compilers, I do agree that compilation problems are everywhere.

In front-end work, where I started off, there's a glut of frameworks.
React, Angular, Vue, Svelte, with some tooling like webpack, parcel,
esbuild, babel and browserify.

What do they all have in common? They're all compilers. React takes JSX
and turns it into HTML and JS.

Angular launched Typescript, which is a language that compiles to
Javascript.

Vue has `.vue` templates, which compile to HTML, CSS, and JS.

Svelte has its own `.svelte` files.

All the other build tools I mentioned take javascript, minify it,
tree-shake it (dead-code elimination) and bundle it for you so it can be
served on the internet.

All of these are compiler problems.

My favorite language, Rust, has a great deal of compiler work in the
core language and design tradeoffs to make it easy for new people to
adopt and experienced people to enjoy.

In Mobile, Kotlin and Swift, as well as many libraries, all reduce to
compiler problems -- they end up manipulating ASTs to produce better
code, or compile to some bytecode that is executed on the target
platform.

Compiler problems really are everywhere.

Here's another quote from Ras Bodik:

> Don’t be a boilerplate programmer. Instead, build tools for users and other programmers. Take historical note of textile and steel industries: do you want to build machines and tools, or do you want to operate those machines?

Got the message? Compilers are really important. Or so I think. But how
does one learn compilers? Well, let's scour the internet.

## A Plan of Attack

There's no shortage of great materials on compilers on the internet, but
I want to focus on three resources I'm currently using to learn
compilers, since I think they run the gamut: One's a great starting
resource, another is a great medium level resource, and one is extremely
hard but rewarding.

The Resources:

1. <https://keleshev.com/compiling-to-assembly-from-scratch/>
2. <https://craftinginterpreters.com/>
3. <https://github.com/rui314/chibicc>

## Compiling to Assembly from Scratch

Compiling to Assembly from Scratch is the first resource I looked at to
start my compiler writing journey. It's a short book on how to write a
small ARM32 emitting compiler in Typescript. It does this by parsing
using a parser combinator, and then emitting simple ARM32 code using the
visitor pattern.

Parser combinators are a technique for parsing that's been picking up
steam recently. Because Typescript has first-class regex, this technique
really fits well here.

The book also goes over basic ARM32 instructions, and at the end of this
pretty short book (~200 pages), you have a working compiler that turns a
subset of javascript into ARM32.

Worth every penny.

## Crafting Interpreters

Crafting Interpreters is a great book -- the first half of the book
covers writing a tree-walk interpreter in Java, while the second half of
the book involves writing a bytecode VM in C for a non-trivial language
called "Lox".

Bob Nystrom really knows his stuff -- the prose is clean, and every line
of code written is well explained.

That being said, for the first part, I didn't really want to write any
Java (sorry Oracle), so I found a transcription of the first part of the
book's code in Rust <https://github.com/jeschkies/lox-rs> and used that
code as the basis for the first part of the book.

At the end of the first part of the book, I really felt as though I got
the hang of the basics of compiler writing.

I still need to go through the second part, but I'm really enjoying it
so far!

## ChibiCC

This resource is a bit different: It's a git repo by the creator of mold
(the new LLVM linker) to create a C Compiler (CC) in C.

This repository follows the paper "An Incremental Approach to Compiler
Construction" by Ghuloum, <http://scheme2006.cs.uchicago.edu/11-ghuloum.pdf> which advocates writing a simple compiler step by step and adding functionality little by little.

Rui Ueyama, the author of this repo, writes clean C code for every
commit, and each message details adding a new feature to the C
compiler. There's no accompanying instructional material, so you're on
your own to read the diffs and try to ascribe meaning to them, but it is
important to read lots of code, and what better way to start than in
such a structured format?

## Conclusion

After going through a few resources for compiler construction, I'm
starting to get a better understanding of compilers, and seeing those
kinds of problems crop up all the time. Writing compilers has also
motivated me to read more code, and I'm hoping to be able to read code
from larger projects to write better code in the future!
