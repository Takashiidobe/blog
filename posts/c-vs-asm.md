---
title: "C vs. Asm"
date: 2025-11-12T08:22:49-05:00
draft: false
---

## It's faster in Assembly

A common refrain is if something is slow, to rewrite it in a
**faster** language. For python, if your python is slow, to write the hot
parts in C. For C, to write your code in pure assembly.

Let's put that to the test.

I have this code here that defines `strnlen` from linux's m68k tree.
This computes `strnlen` as you would expect.


```c
static inline size_t strnlen_asm(const char *s, size_t count)
{
	const char *sc = s;

	asm volatile ("\n"
		"1:     subq.l  #1,%1\n"
		"       jcs     2f\n"
		"       tst.b   (%0)+\n"
		"       jne     1b\n"
		"       subq.l  #1,%0\n"
		"2:"
		: "+a" (sc), "+d" (count));
	return sc - s;
}
```

The c translation here would look like this:

```c
static inline size_t strnlen(const char *s, size_t count)
{
    const char *sc = s;
    while (count--) {
        if (*sc++ == '\0') {   
            sc--;              
            break;
        }
    }
    return sc - s;
}
```

Now if we compile with `-O0`, we'll see that the asm version is better,
even though functionally, they're pretty much the same. The compiler
does only a few optimizations in `-O0`, so the generated code is quite
poor.

```asm
strnlen_asm(char const*, unsigned long):
    link.w %fp,#-4
    move.l %fp@(8),%fp@(-4)
    move.l %fp@(-4),%d1
    move.l %fp@(12),%d0
    movea.l %d1,%a0
    subq.l #1,%d0
    bcss 1e <strnlen_asm(char const*, unsigned long)+0x1e>
    tstb %a0@+
    bnes 14 <strnlen_asm(char const*, unsigned long)+0x14>
    subq.l #1,%a0
    move.l %a0,%fp@(-4)
    move.l %d0,%fp@(12)
    move.l %fp@(-4),%d0
    sub.l %fp@(8),%d0
    unlk %fp
    rts
```

```asm
strnlen(char const*, unsigned long):
    linkw %fp,#-4
    move.l %fp@(8),%fp@(-4)
    bras 5a <strnlen(char const*, unsigned long)+0x28>
    move.l %fp@(-4),%d0
    move.l %d0,%d1
    addq.l #1,%d1
    move.l %d1,%fp@(-4)
    movea.l %d0,%a0
    moveb %a0@,%d0
    seq %d0
    negb %d0
    beqs 5a <strnlen(char const*, unsigned long)+0x28>
    subq.l #1,%fp@(-4)
    bras 6e <strnlen(char const*, unsigned long)+0x3c>
    move.l %fp@(12),%d0
    move.l %d0,%d1
    subq.l #1,%d1
    move.l %d1,%fp@(12)
    tstl %d0
    sne %d0
    negb %d0
    bnes 3e <strnlen(char const*, unsigned long)+0xc>
    move.l %fp@(-4),%d0
    sub.l %fp@(8),%d0
    unlk %fp
    rts
```

However, as soon as we up the optimization for the C version (this time
at `-O2`), the code looks much better:

```asm
strnlen(char const*, unsigned long) [clone .constprop.0]:
    lea 0 <strnlen(char const*, unsigned long) [clone .constprop.0]>,%a0
    tstb %a0@
    beqs 14 <strnlen(char const*, unsigned long) [clone .constprop.0]+0x14>
    addq.l #1,%a0
    cmpa.l #0,%a0
    bnes 6 <strnlen(char const*, unsigned long) [clone .constprop.0]+0x6>
    move.l %a0,%d0
    subi.l #0,%d0
    rts
```

But the assembly version also improves.

```asm
strnlen_asm(char const*, unsigned long) [clone .constprop.0] [clone .isra.0]:
    lea 0 <strnlen(char const*, unsigned long) [clone .constprop.0]>,%a0
       R_68K_32 .rodata.str1.1
    move.q #8,%d0
    subq.l #1,%d0
    bcss 30 <strnlen_asm(char const*, unsigned long) [clone .constprop.0] [clone .isra.0]+0x12>
    tstb %a0@+
    bnes 26 <strnlen_asm(char const*, unsigned long) [clone .constprop.0] [clone .isra.0]+0x8>
    subq.l #1,%a0
    rts
```

## But what about at `-O3`?

However, the real changes happens at `-O3` which has very aggressive
inlining: let's say our program is:

```c
int main() 
{
    size_t n = strnlen_asm("hello", 8);
    size_t c = strnlen("hello", 8);

    return n + c;
}
```

What's the resulting assembly when compiled at `-O3`?

```asm
main:
	lea .LC0,%a0 | < this provides %a0 as the first arg
	moveq #8,%d0 | < and 8 as the second arg
#APP | < this is the start of the assembly version
| 5 "test.c" 1
	
1:     subq.l  #1,%d0
       jcs     2f
       tst.b   (%a0)+
       jne     1b
       subq.l  #1,%a0
2:
| 0 "" 2
#NO_APP | < this is the end of the assembly version
	move.l %a0,%d0 | < this stores the result in %d0
	sub.l #.LC0-5,%d0 | the var c gets folded into the sub.l to add 5.
	rts
```

You'll note `lea` to `move.l` are the assembly version. So, the C code
itself is folded into a constant `5`.

In this case, the C version is much better than the assembly version.

The problem is visibility. The assembly code **can not** be optimized
past what is provided inline + its dependencies (loads in and stores
out). Thus, the optimized assembly version **can never** be optimized
past this:

```asm
	lea .LC0,%a0
	moveq #8,%d0
1:     subq.l  #1,%d0
       jcs     2f
       tst.b   (%a0)+
       jne     1b
       subq.l  #1,%a0
2:
	move.l %a0,%d0
```

Whereas for the C version, we saw it could range from pretty bad code to
a constant which is folded into a previous instruction, which is as
optimal as can be. 

## Why this matters

This problem comes up a lot in areas other than OS programming -- for a
database, you could choose to have a static query plan for a given
query. Since query plans are generally chosen dynamically for a given
query, this gives you stable performance + less overhead per query
because there's no overhead in having to choose a given query plan.
However, you give up future optimizations -- if there's a new version of
your database that can optimize your query, you'll lose out on that --
and for databases, this can be much more than a 100x improvement, that
you get for free just by upgrading, that you can't get with static query
plans.

For compilers, JITs work their magic by having visibility into running
code. If a JIT has to run code that it does not have visibility into, to
maintain correctness, it **must not** optimize that code in any way.
Thus, any optimizing program that has no visibility into the code it
runs **can never** optimize the program at all, lest it break
correctness. Thus, in language design, there's a fundamental tension
between higher-level and lower-level constructs. Lower-level constructs
are easier to optimize now, because they're closer to the machine.
Higher-level constructs may have some overhead now. In the future,
however, higher-level constructs may do better than lower-level
constructs -- because they can provide the compiler with more visibility
and thus more chances for optimization. Thus, languages that are higher
level tend to do better over time -- think Lisp vs. COBOL -- Lisp was
much higher level and had much more overhead at the time, but compilers
can optimize most of it away now.

Declarative languages, like CSS, SQL, and prolog, will probably never
die -- the user offloads the complexity of their tasks to the language
implementer, and grants them higher visibility which let the runtime
choose creative paths toward optimization.

Maybe we should all be writing Haskell.
