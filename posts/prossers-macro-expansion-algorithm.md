---
title: "Macro Expansion With Prosser's Algorithm"
date: 2026-09-28T07:43:52-04:00
draft: false
---

More talk about [Slate](https://github.com/takashiidobe/slate),
a C to Rust translator. Today's topic is the C preprocessor, which
I butchered the implementation of before falling back to the trusty (and
standards approved) Prosser's Algorithm. Let's get into it.

Slate used to expand macros a line at a time, with a set of currently
disabled macro names to prevent recursion. This worked for a lot of
code. Then a line in glibc's `signal.h` broke preprocessing in over
300 translation units.

The macro name and its opening parenthesis were on different lines.
Slate's line-merging code tracked parens, but there wasn't an open
paren on the first line to tell it to keep reading.

```c
#define ID(x) x
#define ALIAS ID

ALIAS
(42)
```

This should be `42`. `ALIAS` expands to `ID`, and the next token is
`(`, so we have a function-like macro invocation. The newline should be
irrelevant.

## First, keep track of state

We'll start with a recursive macro:

```c
#define A B
#define B A

A
```

Repeated substitution would never stop. The correct output is `A`:
when a macro name appears again through its own expansion, that
occurrence must stay unexpanded.

Prosser calls this a "hide set", which is a set of macros a token can't
expand anymore.

The preprocessor sees something like:

```text

  token       hide set

    A         {empty}
    |
    v
    B           {A}
    |
    v
    A           {A, B}    # stop here, don't expand A.
```

An important point is that each hideset is scoped per token. Another `A` elsewhere
in the source can still expand.

Once a recursive token has been produced, it
must keep its hide set even if it's substituted into another macro.

Here's a regression case from GCC's test suite:

```c
enum { a = 4, f = 3 };

#define A(x) (x+2)
#define B(x) A(x)+1
#define f a+f

char array[B(f) == 10 ? 1 : -1];
```

`f` expands to `a+f`, with that second `f` hidden. Substituting it
through `B` and `A` must preserve the set:

```text
  B(f) -> A(a+f)+1 -> (a+f+2)+1
              ^           ^
              +-----------+--- f stays hidden
```

The result is `4 + 3 + 2 + 1`, or `10`. If rescanning drops the set
when the expansion stack unwinds, `f` expands again and we get the
wrong expression, or recurse forever.

## Don't hide too much, either

Function-like macros have a obvious hideset rule. They
use the intersection of the macro name's hide set and the closing
parenthesis's hide set, then add the macro being expanded. That set is
added to the substituted tokens' existing hide sets.

Why the intersection? Here's another regression case:

```c
#define glue(x, y) x ## y
#define xglue(x, y) glue(x, y)

glue(xgl, ue)(1, 2)
```

This should expand to `12`:

```text
  glue(xgl, ue)(1, 2)
          |
          v
     xglue(1, 2)
          |
          v
      glue(1, 2)
          |
          v
          12
```

The produced `xglue` token hides `glue`, but its closing `)` came from
the original source and has an empty hide set. Their intersection is
empty. We add `xglue`, so the replacement's `glue` is free to expand.
Blindly carrying the name's whole hide set would incorrectly leave
`glue(1, 2)` in the output.

The core rules in [Prosser's algorithm](https://www.spinellis.gr/blog/20060626/cpp.algo.pdf)
are:

```text
  object-like macro M:
      H(name) | {M}

  function-like macro M(...):
      (H(name) & H(closing paren)) | {M}
```

Substitution still needs the usual rules for arguments: prescan normal
uses, keep raw tokens for stringizing and pasting, then rescan the
replacement with the remaining input. Hide sets don't replace those
rules; they tell us which names remain eligible along the way.

## References

- [Prosser's algorithm](https://www.spinellis.gr/blog/20060626/cpp.algo.pdf)
- [chibicc's preprocessor](https://github.com/rui314/chibicc/blob/main/preprocess.c)

For a concrete impl, chibicc's preprocessor
is a good place to read about the algorithm. It's much easier to
follow once you've seen a few examples of what the hide sets prevent.
