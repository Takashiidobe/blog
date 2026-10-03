---
title: "Making Translated SQLite 53 Times Faster"
date: 2026-10-02T11:27:39-04:00
draft: false
---

More talk about [Slate](https://github.com/takashiidobe/slate),
a C to Rust translator! In [Switch To Match](./switch-to-match.md),
I talked about recovering structured Rust from C's control flow.
This time, we get to see what that does to a real program.

Over the past month slate moved off of using clang-ir to generate code,
and now uses its own pipeline that emits its own internal IR. This
allows slate to be run without requiring clang, and also allows slate to
emulate multiple compilers, like gcc, msvc, and clang (although the
clang path is the most tested so far).

A recent milestone was knocking out the lowering features that now
allows slate to translate SQLite from C to Rust.

Slate could translate SQLite and run its CTE benchmark correctly.
Unfortunately, the generated Rust was ~60 times slower than C. If you
remember the post about how glowingly I said the folklore version
of the structured programming theorem was good to lower switches and
gotos, but when I saw the CTE benchmark I knew exactly what the
regression was. Keep in mind the C version runs in about 0.47s on my
machine, compared to the 26.5s the first rust run did.

| Change               | Runtime | Improvement |
| -------------------- | ------: | ----------: |
| Statement dispatcher | 26.584s |         N/A |
| Basic blocks         |  2.703s |       9.84x |
| Recovered structure  |  0.501s |       5.40x |

## An interpreter for your switches and gotos

C has `goto`, and (thankfully) Rust doesn't.

Here's a small example:

```c
unsigned sum(unsigned n) {
    unsigned total = 0;
    unsigned i = 0;
again:
    if (i >= n) goto done;
    total += i;
    i += 1;
    goto again;
done:
    return total;
}
```

The lowering pass would give individual statements or evaluations their
own states. For our example, that looks like:

```rust
fn sum(n: u32) -> u32 {
    let mut total = 0u32;
    let mut i = 0u32;
    let mut state = 0usize;

    loop {
        match state {
            0 => state = if i >= n { 4 } else { 1 },
            1 => {
                total = total.wrapping_add(i);
                state = 2;
            }
            2 => {
                i = i.wrapping_add(1);
                state = 3;
            }
            3 => state = 0,
            4 => return total,
            _ => unreachable!(),
        }
    }
}
```

This works. It's also asking the compiler to undo quite a lot of work.
Even `total += i; i += 1;` becomes two trips through a loop.

SQLite already has a virtual machine, which dispatches SQL
bytecode instructions. For gotos and switches, Slate adds another
dispatcher _inside_ that interpreter, between ordinary statements
in each opcode.

This commit's `sqlite3VdbeExec` was
1.17 MB of machine code in slate, compared to 52 KB for Clang's version.
In the original CTE profile, 63% of cycles landed in just the translation
dispatcher's header.

That header was doing a lot of stack copying, which couldn't be
coalesced to registers, whereas the C version was written to be
optimized so compilers could find that optimization.

## First change: stop dispatching between statements

The first fix was to form basic blocks: sequences of operations with one entry, where
execution proceeds straight through to the final branch or jump.

```
  before:                      after:

  +-------------+              +-------------+
  | total += i  |              | total += i  |
  +------+------+              | i += 1      |
         |                     +------+------+
         v                            |
    dispatcher                        v
         |                       dispatcher
         v
  +-------------+
  | i += 1      |
  +------+------+
         |
         v
    dispatcher
```

For our example, the loop body and its jump can share an arm:

```rust
loop {
    match state {
        0 => state = if i >= n { 2 } else { 1 },
        1 => {
            total = total.wrapping_add(i);
            i = i.wrapping_add(1);
            state = 0;
        }
        2 => return total,
        _ => unreachable!(),
    }
}
```

We also bypassed empty forwarding jumps and removed unreachable nodes.
The important constraint is that a block must stop wherever control
could enter from another path. If a `goto` targets `i += 1`, we can't
merge it into `total += i`: entering there would incorrectly add to
`total` too. Entry points, joins, and branch targets stay separate.

In SQLite, this cut the dispatcher from 3,696 states to 1,130, and the
CTE runtime from 26.584s to 2.703s. Almost 10 times faster from letting
consecutive statements be consecutive statements!

But the common header was still there. The coalesced profile still
spent 45.26% of sampled CTE cycles in it.

## Second change: recover the loop

Our example doesn't actually need a state variable. We know where the
back edge goes, and we know which condition exits the loop, so let's
rewrite it like this:

```rust
fn sum(n: u32) -> u32 {
    let mut total = 0u32;
    let mut i = 0u32;

    while i < n {
        total = total.wrapping_add(i);
        i = i.wrapping_add(1);
    }
    total
}
```

This is much easier for a compiler to read and nets us much better code.

Some C graphs have cycles with multiple entry points. Those still need
a small local selector. The goal is to keep dispatch around the region
that needs it, rather than make the whole function pay for it.

After this change, `sqlite3VdbeExec` had zero transfers through the
function-wide translation dispatcher. One local selector remained,
along with SQLite's own opcode dispatch.

CTE dropped from 2.703s to 0.501s: another 5.4x faster.

## How fast are we?

Timings are most important, but we can also count retired instructions for the
whole CTE run:

| Version              | Instructions executed |
| -------------------- | --------------------: |
| Statement dispatcher |       227.127 billion |
| Basic blocks         |        29.183 billion |
| Recovered structure  |         6.204 billion |
| Clang                |         5.708 billion |

The generated version went from executing about 40 times as many
instructions as C to about 9% more. The VDBE's machine code shrank from
1.17 MB to 35 KB. That's smaller than Clang's side, which is a good
sign.

## Lessons Learned

LLVM might be magical, but it can't optimize away everything.
Here, the actual way you write your source code matters; rewriting the
source code made for a 50x speedup. Simpler code = better performance,
and in highly optimized loops like sqlite's
bytecode, it can mean a lot.

In the future, I'm thinking about maybe going even further; it's
possible to turn irreducible gotos into TCO'd functions with the new
`become` keyword, which is basically hand designed for hot loops like
this.
