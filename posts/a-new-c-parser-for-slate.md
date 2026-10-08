---
title: "A New C Parser for Slate"
date: 2026-10-06T21:14:20-04:00
draft: false
---

Last week I got slate's frontend off of clang-ir and onto a handmade C
parser (not compiler). It's on crates.io
[here](https://crates.io/crates/slate-parser)
and there's a [web](https://slate-parser.takashiidobe.com) version of it
too.

## Why Switch?

I was honestly fairly satisfied with clang-ir while building slate.
Clang and clang-ir (which I might call CIR for the rest of this post)
handle all the ambiguities and problems with parsing C. This stuff is
not easy. CIR is also just the right level of abstraction; it properly
handles stuff like type widths (chars turn into i8s or u8s, depending on
target), resolves types, turns target independent types like `size_t`
into their correct widths (mainly `u32` and `u64`). Really, it's great.
I had a few problems using it though which led me to make the switch:

1. It's not built by default in clang

This is the big one; since CIR is not enabled by default in mainstream
clang, nobody will have a system clang that slate could use. That means
users of slate (a rust crate) have to build their own llvm (ouch, since
on my laptop this takes about 45 minutes), and enable some feature
flags. A build of LLVM is also many GBs, so this is a nonstarter for
lots of people. With a rust binary on crates.io, I can provide prebuilt
binaries for any target, and compiling slate from source is not that bad
(cue rust compiler performance groans). Hey, at least it's not building
clang from source (more groans).

2. CIR is primarily used for optimization

I had a long list of bugs where CIR couldn't parse a C project that
clang could, or run into an NYI (not yet implemented), or get into many
cases where CIR would remove or emit IR that didn't match my
understanding of the C. I ran into about 50 of these going through the
gcc torture tests, filed umbrella tickets for most of these,
and then of course, had to wait. CIR is slated to be stable in a while
(within the year?), but for now, of course, there's lots more to work on
than some gcc torture bugs, and the main consumers are GPUs optimizers,
so I get that slate will have a different use case than what CIR is
primarily used for currently.

3. Lowering hacks

I could hack around some of the previous things, but this required a lot
of infrastructure. I had a macro provenance dump plugin (since this is
provided by libclang and not bare clang-ast or the CIR), some extra
patches to llvm on my branch to help with other provenance issues, had
to generate clang-ir ops which were constantly in flux, and had to make
the lowerer difficult to work with and had to add a lot of regression
testing. Any rebuild of CIR enabled clang would cause some sort of bug,
whether it be a hack no longer being required because CIR fixed
something, or a new hack required because CIR changed semantics. This
sort of drudgery wasn't really the focus of the project, so it was a bit
unfortunate to spend time on.

4. Hosting on the web

With wasm, hosting a rust binary on the frontend, even a compiler is
easy. [Hosting my wip SML implementation](https://nassau.takashiidobe.com/)
was a cinch; you just compile to wasm and you're good to go. For slate,
with the old CIR, I needed a custom clang, which means I need a backend.
I also need access to the filesystem, and opens up security issues; if
you give people a backend, they can hack it. My existing VM would've
sufficed, but it's arm64 (thank you hetzner for saving me money with
ARM), but in this case my development machine is x86_64, so I can't send
the server a copy of my built clang. I would've had to build llvm on it
(8GB of memory, and 80GB of hard disk space), which would've taken a
fairly long time, or try to put it on github actions, or do something
else in the meanwhile. On top of that, I would have to spend time
sandboxing, putting it behind cloudflare, etc. This is really less than
ideal. I decided to put the hosted web version behind a `blwrap`
sandbox on a fresh x86_64 vm, but this cost me about $12/month (thanks
CPU shortage) just for this project. That's one chipotle burrito.

5. Performance

One current issue with CIR is needing to save CIR along with the
clang-ast, since some information is preserved in just the ast, and not
yet copied over to CIR. That means you basically have to use enough
memory to parse to AST, and also emit IR. For example, comparing slate's
C parser to clang-ir to compile chibicc:

|             |     slate |  clang-ir |
| ----------- | --------: | --------: |
| memory used | 33.55 MiB | 80.05 MiB |
| time        |  0.3325 s |  0.3248 s |

slate uses a lot less memory, because the serialized clang-ast is pretty
large for some projects.

## All the rest

The first reason why switching is interesting, I was able to get rid of
the old setup and have `slate.takashiidobe.com` run purely on the
frontend. That means no more security issues!

Another thing is that I
could emulate different compilers. For example, gcc and clang disagree
on the semantics of certain programs, for example, what inline asm does,
or how atomics are lowered. By having our own C parser, I can emulate
either side based on what compiler the user wants to build with. So code
that relies upon that gcc behavior can be compiled by slate now that
wasn't doable in the old slate.

Another perk is being able to handle comments and macros provenance more
easily, since that required extra infra in the clang-ir side.

CIR itself doesn't handle all types either, e.g. bitints larger than 128
bits, or Decimal types. Slate can support that now (pretty easily, since
all it needs to do is parse it), and the existing lowering can just
handle it.

The cons are pretty obvious; I had to make a c parser, and also throw
out most of my CIR based lowerer in slate. I could clean it up, but lost
lots of test coverage in the meanwhile, but after a bit more polish, we
should be able to get back to slate's old numbers, and also handle gcc
and msvc flavored C, which is a big improvement (especially handling
msvc, and its inline asm).

But the biggest pro, in my opinion, for having everything in rust, is a
pure rust build, which means no cumbersome setup. Just install one
binary, and you're ready to go. That's the kind of UX I want out of any
tool, and that's why I'm glad to have made the switch.
