---
title: "Switch To Match"
date: 2026-09-02T18:03:41-04:00
draft: false
---

More talk about [Slate](https://github.com/takashiidobe/slate),
a C to Rust translator! Take a look at the previous post here:
[One libc for all](./one-libc-for-all.md).

Today's topic is about translating C's `switch` to rust's `match`, which
shockingly has a decent amount of literature about it (unbeknownst to
me).

We'll start out with this example which demonstrates the main features
of switch in C:

```c
int score(int x) {
  int out = 0;
  switch (x) {
  case 1:
    out += 10;
  case 2:
    out += 20;
    break;
  case 3:
  case 4:
    out += 40;
    break;
  default:
    out += 90;
  }
  return out;
}

int main(void) {
  printf("%d %d %d %d %d\n", score(1), score(2), score(3), score(4), score(5));
  return 0;
}
```

- `score(1)` hits the first branch, where it adds `10` to out. However,
  there is no break after 1, so it also falls through into case 2, which
  adds `20` to out. Thus, out will be `30` and printed.
- `score(2)` increments out by 20 and then breaks out. So it prints out
  `20`.
- `score(3)` hits the 3 or 4 branch, increments out by `40` and prints.
- `score(4)` does the same thing, printing `40`.
- `score(5)` will just print out `90`, since even without a break it
  falls through into nothing.

If we were to draw a graph of this, it would look like:

```
                    ┌─────────────┐
                    │  entry      │
                    │  out = 0    │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  switch(x)  │
                    └──┬──┬──┬──┬─┘
          x==1         │  │  │  │ default
      ┌────────────────┘  │  │  └────────────────────┐
      │            x==2   │  │ x==3,4                │
      │            ┌──────┘  └────────┐              │
      │            │                  │              │
      ▼            ▼                  ▼              ▼
┌───────────┐   ┌───────────┐    ┌───────────┐ ┌───────────┐
│ case 1:   │   │ case 2:   │    │ case 3:   │ │ default:  │
│ out += 10 │──▶│ out += 20 │    │           │ │ out += 90 │
└───────────┘   └─────┬─────┘    └─────┬─────┘ └─────┬─────┘
                      │                │             │
                      │                ▼             │
                      │          ┌───────────┐       │
                      │          │ case 4:   │       │
                      │          │ out += 40 │       │
                      │          └─────┬─────┘       │
                      │                │             │
                      └──────┬─────────┴─────────────┘
                             ▼
                      ┌─────────────┐
                      │ return out  │
                      └─────────────┘
```

We could try to convert this to rust but sadly, rust's match doesn't
have fallthrough. So we'll have to be a bit more creative.

## Recovering Structure

There's a theorem from the 60s (the structured program theorem) saying
any Control Flow Graph (CFG) can be represented with three control flow
structures: sequence, selection (if/else), and iteration (a loop over a
boolean condition).

There are many ways of recovering structure, so let's look at three
concrete ways of converting switch to match: how C2Rust's relooper does
it, and the classic "folk theorem" construction using a loop and
a program counter, and then a bottom up traversal algorithm that
generates the best results.

## Relooper

C2Rust currently emits this for the switch case in C we looked at, using
an algorithm called Relooper:

```rust
's_34: {
    match x {
        1 => {
            out += 10;
        }
        2 => {}
        3 | 4 => {
            out += 40;
            break 's_34;
        }
        _ => {
            out += 90;
            break 's_34;
        }
    }
    out += 20;
}
```

Relooper's trick is when code is shared by multiple branches but
some branches need to skip it, it wraps the branch in a labeled
block and has those branches break out of the label before reaching
the shared code. So:

- `out += 20` (case 2's body) is hoisted outside and after the `match`,
  since it's the code shared by case 1's fallthrough and entering case
  2 directly.
- Every case that must _not_ run that trailing code (3, 4, `default`)
  gets an explicit `break 's_34`, so it doesn't run into the `out += 20`
  code.
- Case 1 has no break, so it falls off the end of its arm into the
  shared trailer, which executes `out += 20`.
- Case 2's own arm is deleted, because its body _is_ the shared trailing
  code.

Basically, Relooper will add an outer loop with break label for every
fallthrough case, minus 1. So in this case, let's count the fallthroughs:

```c
switch (x) {
case -500 ... -1: // 1
  out += 100;
case 0:
case 1: // 2
  out += 1;
case 2 ... 100: // 3
  out += 2;
  if (out > 50) {
    break;
  }
  out += 3;
case 101: // 4
  out += 4;
  if (x % 2 == 0) {
    break;
  }
default: // 5
  out += 5;
case 200 ... 500:
case 600:
case 700 ... 900:
  out += 6;
  break;
case 999: // 6
  out += 7;
case 1000: // 7
  out += 8;
}
```

Since there are 7 fallthroughs, there will be 6 wrapping loops
generated, making this code hard to read:

```rust
's_73: {
    'c_720: {
        'c_700: {
            'c_698: {
                'c_695: {
                    'c_704: {
                        match x {
                            -500 => {
                                out += 100 ;
                            }
                            0 | 1 => {}
                            2 => {
                                break 'c_695;
                            }
                            101 => {
                                break 'c_698;
                            }
                            200 | 600 | 700 => {
                                break 'c_720;
                            }
                            999 => {
                                out += 7;
                                break 'c_704;
                            }
                            1000 => {
                                break 'c_704;
                            }
                            _ => {
                                break 'c_700;
                            }
                        }
                        out += 1;
                        break 'c_695;
                    }
                    out += 8;
                    break 's_73;
                }
                out += 2;
                if out > 50 {
                    break 's_73;
                } else {
                    out += 3;
                }
            }
            out += 4;
            if x % 2 == 0 {
                break 's_73;
            }
        }
        out += 5;
    }
    out += 6;
}
```

## The Structured Programming Theorem: Folk version

The folk theorem of the structured programming theorem has a simple
kernel: interpret the unstructured part as a subprogram
and hand-write a tiny interpreter for it.

We create a value that's our program counter (in this case,
`__switch_case0`). Since the switch only checks `x`, we can assign this
to `x`, and map the different case branches (1,2,3,4,default) to one
number per distinct case (0,1,2,3,4).

Afterwards, we enter the interpreter and interpret the program. Any node
that has a break, say 1, 3, 4 (which line up with the switches that have
breaks in the C program break out of the loop immediately. To handle
fall through, the cases set `__switch_case0` to the next execution. In
this case, since we only have fallthrough, it will always be the next
block (0 sets `__switch_case0` to 1), (2 sets `__switch_case0` to 3).
This program emulates the C's switch code perfectly.

```rust
{
    let mut x = 1; // what we call the function with, in this case 1
    {
        // the mapping of switch cases to unique blocks:
        let mut __switch_case0: i32 = match x {
            1 => 0,
            2 => 1,
            3 => 2,
            4 => 3,
            _ => 4,
        };
        '__switch0: loop {
            match __switch_case0 {
                0 => {
                    out += 10;
                    // in the fallthrough case, we increment __switch_case by 1
                    // and then continue
                    __switch_case0 = 1;
                    continue '__switch0;
                }
                1 => {
                    out += 20;
                    // for a fallthrough case we generate a break. This
                    // can be elided, but it's left here to be explicit
                    break '__switch0;
                }
                2 => {
                    __switch_case0 = 3;
                    continue '__switch0;
                }
                3 => {
                    out += 40;
                    break '__switch0;
                }
                4 => {
                    out += 90;
                    break '__switch0;
                }
                _ => {
                    break '__switch0;
                }
            }
        }
    }
}
```

This version is worse than what relooper generates. However, for the
7 fallthrough version, note that we're guaranteed only one outer loop
for our match, because the dispatcher (`__switch_case0`) at the top
handles control flow.

Personally, I find this much more readable than 7 nested levels, so I
chose this as the default lowering representation of a switch.

```rust
{
    let mut out: i32 = 0;
    {
        let __switch_value0 = ...; // whatever the value is
        let mut __switch_case0: i32 = match __switch_value0 {
            -500..=-1 => 0,
            0 => 1,
            1 => 2,
            2..=100 => 3,
            101 => 4,
            200..=500 => 6,
            600 => 7,
            700..=900 => 8,
            999 => 9,
            1000 => 10,
            _ => 5,
        };
        '__switch0: loop {
            match __switch_case0 {
                0 => {
                    out += 100;
                    __switch_case0 = 1;
                    continue '__switch0;
                }
                1 => {
                    __switch_case0 = 2;
                    continue '__switch0;
                }
                2 => {
                    out += 1;
                    __switch_case0 = 3;
                    continue '__switch0;
                }
                3 => {
                    out += 2;
                    if out > 50 {
                        break '__switch0;
                    }
                    out += 3;
                    __switch_case0 = 4;
                    continue '__switch0;
                }
                4 => {
                    out += 4;
                    if x % 2 == 0 {
                        break '__switch0;
                    }
                    __switch_case0 = 5;
                    continue '__switch0;
                }
                5 => {
                    out += 5;
                    __switch_case0 = 6;
                    continue '__switch0;
                }
                6 => {
                    __switch_case0 = 7;
                    continue '__switch0;
                }
                7 => {
                    __switch_case0 = 8;
                    continue '__switch0;
                }
                8 => {
                    out += 6;
                    break '__switch0;
                }
                9 => {
                    out += 7;
                    __switch_case0 = 10;
                    continue '__switch0;
                }
                10 => {
                    out += 8;
                    break '__switch0;
                }
                _ => {
                    break '__switch0;
                }
            }
        }
    }
}
```

Now let's do better. Note that the CFG
only goes one direction (down). So each node in the CFG does the following:

1. Executes its block
2. Either (breaks to end or falls through to the next branch)

We can use this to optimize our representation of our match by taking
the switch case bottom up. The rules are simple:

- `default` is translated to `_`. Keep in mind that `default` can
  fallthrough (`_` in rust cannot) so we must always move the `_` pattern
  to the end of the switch case and handle fallthrough.
- We traverse the switch case bottom-up, and collect the blocks we've
  seen in reverse order and the labels we've seen. On break, for each
  label we'll write the blocks we've seen in reverse order (since we're
  traversing in reverse, this will write out the blocks in the proper
  order) for each label we've seen. Then we'll clear our cache of blocks
  and labels.
- We stop when we hit the start of the block and clear our current cache
  of blocks and labels.

Since this is a straight-line construction, we can prove this with
induction:

_Invariant:_ right before we process case `i`, the buffer holds exactly
the code that runs when control jumps into case `i + 1`'s label and
executes until the next `break` or the end of the switch.

_Step:_ if case `i` has no break, prepending its block to the buffer
gives exactly the code that runs from a jump into case `i`'s label, so
the buffer now satisfies the invariant for `i`. If case `i` has a break,
the buffer for `i` is just its own block, since nothing after it is ever
reached from a jump to `i`.

So by induction, the buffer at the moment we flush label `L` always
equals C's fallthrough semantics for entering at `L`
which is exactly what a `match` arm needs to contain.

So let's run through this example:

| Step | What we see (bottom-up)          | Buffered blocks        | Buffered labels | Emitted                                            |
| ---- | -------------------------------- | ---------------------- | --------------- | -------------------------------------------------- |
| 1    | `default:` block `out += 90`     | `out += 90`            | `_`             | -                                                  |
| 2    | end of switch (implicit break)   | -                      | -               | `_ => out += 90`                                   |
| 3    | `break` (before `default`)       | -                      | -               | (clear buffer)                                     |
| 4    | `case 4:` block `out += 40`      | `out += 40`            | `4`             | -                                                  |
| 5    | `case 3:` (empty)                | `out += 40`            | `3, 4`          | -                                                  |
| 6    | `break` (before `case 3`)        | -                      | -               | `3 => out += 40;` `4 => out += 40;` (clear buffer) |
| 7    | `case 2:` block `out += 20`      | `out += 20`            | `2`             | -                                                  |
| 8    | `case 1:` block `out += 10`      | `out += 10; out += 20` | `1, 2`          | -                                                  |
| 9    | start of switch (implicit break) | -                      | -               | `1 => out += 10; out += 20;` `2 => out += 20;`     |

That gets us this:

```rust
match x {
    1 => {
        out += 10;
        out += 20;
    }
    2 => {
        out += 20;
    }
    3 => {
        out += 40;
    }
    4 => {
        out += 40;
    }
    _ => {
        out += 90;
    }
}
```

We can converge identical blocks, so note 3 and 4 are the same, so the
block can be deleted and the label for 3 can be replaced with either `|`
for or or you can use a range (for types that can).

This gets us:

```rust
match x {
    1 => {
        out += 10;
        out += 20;
    }
    2 => {
        out += 20;
    }
    3 | 4 => {
        out += 40;
    }
    _ => {
        out += 90;
    }
}
```

Which is exactly what I would handwrite in a translation.

With a little range coalescing, this also handles the 7 fallthrough
case:

```rust
match x {
    -500..=-1 => {
        out += 100;
        out += 1;
        out += 2;
        if out > 50 {
        } else {
            out += 3;
            out += 4;
            if x % 2 == 0 {
            } else {
                out += 5;
                out += 6;
            }
        }
    }
    0 | 1 => {
        out += 1;
        out += 2;
        if out > 50 {
        } else {
            out += 3;
            out += 4;
            if x % 2 == 0 {
            } else {
                out += 5;
                out += 6;
            }
        }
    }
    2..=100 => {
        out += 2;
        if out > 50 {
        } else {
            out += 3;
            out += 4;
            if x % 2 == 0 {
            } else {
                out += 5;
                out += 6;
            }
        }
    }
    101 => {
        out += 4;
        if x % 2 == 0 {
        } else {
            out += 5;
            out += 6;
        }
    }
    200..=500 | 600 | 700..=900 => {
        out += 6;
    }
    999 => {
        out += 7;
        out += 8;
    }
    1000 => {
        out += 8;
    }
    _ => {
        out += 5;
        out += 6;
    }
}
```

Some improvement could be made to hoist the `if out > 50 {} else {}` out,
since there are lots of repeated sub blocks here, but that's for another
time.

## Generality ain't all it's cracked up to be

Handling the general case is hard. For C2Rust, relooper is the way to go
because the switch might have a stray goto out of it, and because its
first pass is only transpilation with an optional post-processing pass.

Slate's first lowering pass is pretty similar (I chose to implement the folk
theorem in the lowering phase for its simplicity, even if it has worse
output). However, Slate has an advantage in that it runs
post-processing, so it can consume lowered output and recover structure
from it. Thus, we can apply the bottom up algorithm conservatively
and get the ideal match output from the conclusion for almost every switch.
