---
title: "Inline Assembly Across Compilers"
date: 2026-09-27T11:23:43-04:00
draft: false
---

Let's talk more about [Slate](https://github.com/takashiidobe/slate),
a C to Rust translator, in particular, inline assembly. As a Unix or
gcc/clang user, I thought inline asm would all be
roughly the same shape, but as I would learn later, that's not the case.

Parsing inline asm isn't just about the asm; the compiler also needs to know where
the inputs are, which registers
are overwritten, which memory the instructions might touch, and so on. GCC,
Clang, MSVC, have a different "virtual machine" of instructions for
this. Rust is a different "virtual machine", so we have to first parse
for a specific model and then make sure our translated code can emit
proper rust asm.

## GCC/Clang: show me your inputs and outputs

Here's a GNU-style example that both compilers accept on x86:

```c
int increment(int x) {
    __asm__("addl $1, %0" : "+r"(x) : : "cc");
    return x;
}
```

The `asm` statement has four parts, separated by colons:

1. template
2. outputs
3. inputs
4. clobbers

In the previous example the inputs are empty

- `"addl $1, %0"` is the template. `%0` stands for operand zero, which
  is the first operand listed after the template.
- `"+r"(x)` is the first operand, so it goes in `%0`.
  `r` is a general purpose register,
  and the compiler chooses which one. `+` says it's both read
  and written: `x` is loaded into the register before the asm runs, and
  the register is copied back into `x` afterwards.
- `"cc"` is a clobber, because `addl` modifies the condition codes (the flags
  register), we tell the compiler not to expect any comparison result
  to survive past this asm.

The equivalent Rust could be:

```rust
fn increment(mut x: i32) -> i32 {
    unsafe {
        std::arch::asm!(
            // the `:e` prints the 32-bit register name on x86-64
            "add {x:e}, 1",
            x = inlateout(reg) x,
            options(pure, nomem, nostack),
        );
    }
    x
}
```

`inlateout(reg) x` is `+r`. The options are promises about the asm:
`nomem` says it doesn't touch memory, `nostack` says it doesn't push
anything, and `pure` says it has no side effects, so the compiler may
delete it if the result is unused. There's no `cc` equivalent because
`asm!` assumes the flags are clobbered by default. There's `preserves_flags` to opt out.

The `in`, `out`, `lateout` family exists because the constraint letters
carry more information than I've let on. A plain GNU output constraint,
`=r`, doesn't mean the register must be reserved from the start of the
assembly. The compiler may reuse an input register for it, assuming
inputs are consumed before outputs are written.

An early-clobber output, `=&r`, flips that assumption. It's not safe
because asm might overwrite the output while it still needs the inputs.

The other output constraints line up like this:

| GCC/Clang        | Rust             |
| ---------------- | ---------------- |
| `r` input        | `in(reg)`        |
| `=r` output      | `lateout(reg)`   |
| `=&r` output     | `out(reg)`       |
| `+r` read/write  | `inlateout(reg)` |
| `+&r` read/write | `inout(reg)`     |

Getting this wrong can overwrite inputs or otherwise corrupt the
translated program, but only sometimes, which is the worst kind of bug.

Those are modifiers on the constraint. The letter after them says what
kind of location the operand can live in, and `r` is only one option:

| GCC/Clang                    | Meaning                       | Rust                             |
| ---------------------------- | ----------------------------- | -------------------------------- |
| `r`                          | any general purpose register  | `reg`                            |
| `a`, `b`, `c`, `d`, `S`, `D` | one specific x86 register     | `in("eax")`, `out("ecx")`, ...   |
| `i`, `n`                     | a compile-time constant       | `const`                          |
| `m`                          | a memory location             | no equivalent                    |
| `g`                          | register, memory, or constant | no equivalent                    |
| `rm`, `ri`, ...              | any of the listed letters     | no equivalent                    |
| `0`-`9`                      | same location as that operand | `inout` / `inlateout`, see below |

Specific registers and constants are easy. Rust lets you name the
register directly (except `b`, more on that later), and `"i"(4)` is just
`const 4`.

Memory is the problem. `asm!` has no operand kind for "a memory
location", so for `"m"(x)` slate takes the address of `x`, passes it in
a register, and rewrites `%0` in the template as `[{ptr}]`. The C
compiler could have used any addressing mode it wanted, a plain stack
slot included, and now we've incorrectly forced a register.

`g` and the multi-letter ones are worse. They tell the compiler the asm
works with whichever location it picks, but Rust wants that choice made
up front. So slate chooses to commit to one.

GCC/Clang also allows an input to be tied to an output:

```c
int increment(int x) {
    int result;
    __asm__("addl $1, %0" : "=r"(result) : "0"(x) : "cc");
    return result;
}
```

The `0` means use the same location as output zero. In slate I folded that
pair into one read/write operand. But folding the operand can't move
the input expression's side effects earlier. We keep its original
source operand number so input evaluation still happens in order.

## Memory

Registers are only half of it. The compiler also needs to know if the
asm reads or writes memory that isn't in the operand list. In GCC and
Clang you say so with a `"memory"` clobber:

```c
int data, ready;

void publish(int v) {
    data = v;
    __asm__ volatile("" ::: "memory");
    ready = 1;
}
```

The asm is empty, but the clobber says any memory could have changed.
The compiler can't move the store to `data` past it, and it can't keep
globals cached in registers across it. Most empty asm blocks you'll see
in the wild are this, a compiler barrier.

Rust does it the other way around. `asm!` assumes the block touches
memory unless you say otherwise:

```rust
asm!("", options(nostack, preserves_flags));
asm!("add {x:e}, 1", x = inlateout(reg) x, options(nomem));
```

The first one is a barrier with no options needed. The second promises
not to touch memory, so the compiler is free to move it around or
delete it.

Going from GNU to Rust is easy in one direction: a `"memory"` clobber
just means leaving `nomem` off. The other way is the problem; if the
GNU asm has no `"memory"` clobber, can slate add `nomem`? Only if the
asm has no memory operands, and also, it depends what compiler you ask.

## Differences in ASM between Clang and GCC

Some constraints give you options, e.g. `rm` means register or memory.
Some comma-separated alternatives offer combinations of operand constraints.

Rust wants a concrete operand kind, so Slate has to choose an
alternative that works for every operand together:

```text
  GNU constraint:
        |
        v
  choose one of:
        |
        |--> register ---> Rust register operand
        |--> immediate --> Rust const operand
        |--> memory -----> Address + memory reference in template
```

Comparing clang to GCC, I found GCC preferred a register for `rm` while
Clang preferred memory. That's mostly a perf thing, since Clang keeps a
stack slot around for the memory case and GCC doesn't.

A semantic difference comes from asm volatile. In this example, `ready` is
read but not declared inline:

```c
int ready;

int publish(void) {
    int seen;
    ready = 1;
    __asm__ volatile("movl ready(%%rip), %0" : "=r"(seen));
    ready = 2;
    return seen;
}
```

Note there's no `"memory"` clobber, so GCC takes a literal interpretation: the
asm doesn't touch memory. It sees two stores to `ready` with nothing in
between and deletes the first, so the asm reads the initial value:

```asm
# gcc version
publish:
        movl ready(%rip), %eax
        movl $2, ready(%rip)
        ret
```

Clang assumes volatile asm might touch anything, so it keeps the first
store and the asm reads 1:

```asm
# clang version
publish:
        movl $1, ready(%rip)
        movl ready(%rip), %eax
        movl $2, ready(%rip)
        ret
```

The same function returns 0 or 1 depending on the compiler
([Compiler Explorer](https://godbolt.org/z/5Y9sz3Mrx)). Any asm that
observes memory without saying so, like a syscall the kernel reads a buffer
for or a trap handler that reads a flag, breaks the same way. If your code
relied on the first store happening, it works until someone builds it with
another compiler.

This is programmer error: the asm underspecifies its clobbers, and the
compilers are each free to read that however they like. But the compiler
never looks inside the asm template, so there's nothing to diagnose, and
there's no static analysis that catches it either. The result is plenty of
code in the wild that has underspecified its clobbers for decades and been
chugging along without a care in the world. Slate has to keep that code
behaving the way it did, and "the way it did" depends on which compiler
built it.

## Handling rbx

One more wrinkle, and this one comes from `cpuid`. It takes its leaf in
`eax` and writes `eax`, `ebx`, `ecx` and `edx`. GCC and Clang will
generally let you name `rbx` as an output on x86_64, so C code does this
all the time:

```c
unsigned cpuid_ebx(void) {
    unsigned eax = 1, ebx, ecx, edx;
    __asm__ volatile("cpuid"
                     : "+a"(eax), "=b"(ebx), "=c"(ecx), "=d"(edx));
    return ebx;
}
```

It isn't fine everywhere. On 32-bit PIC, `ebx` holds the GOT pointer and GCC
refuses to let asm claim it. zstd's `lib/common/cpu.h` has a branch just for
this, guarded by `defined(__i386__) && defined(__PIC__) && !defined(__clang__)`:

```c
__asm__(
    "pushl %%ebx\n\t"
    "cpuid\n\t"
    "movl %%ebx, %%eax\n\t"
    "popl %%ebx"
    : "=a"(f7b), "=c"(f7c)
    : "a"(7), "c"(0)
    : "edx");
```

It never names `ebx` as an operand. It saves it, runs `cpuid`, copies the
result into `eax`, and restores it. The same source needs a different asm
body depending on the compiler and target.

Rust has the same restriction. LLVM reserves `rbx` (as a base pointer when
the stack needs realigning, and as the GOT register in 32-bit PIC code), so
`out("ebx") x` is a compile error, and so is listing it as a clobber. Slate
does what zstd does by hand, so the first C function above comes out as:

```rust
fn cpuid_ebx() -> u32 {
    let ebx: u32;
    unsafe {
        asm!(
            "push rbx",
            "mov eax, 1",
            "cpuid",
            "mov {0:e}, ebx",
            "pop rbx",
            out(reg) ebx,
            out("eax") _,
            out("ecx") _,
            out("edx") _,
        );
    }
    ebx
}
```

`rbx` never appears as an operand, so there's nothing for Rust to reject.

## MSVC: no contract at all

MSVC's 32-bit x86 syntax can refer to C variables directly:

```c
int increment(int x) {
    __asm {
        mov eax, x
        add eax, 1
        mov x, eax
    }
    return x;
}
```

Compare that to the GNU version. There you tell the compiler: I read
`x`, I write `x`, I clobber the flags. Here you tell it nothing. You
hand it instructions and it has to work out the rest by reading them.
It finds the references to C objects, resolves their names, and infers
reads, writes and register clobbers.

This is brutal for the compiler. Every mnemonic needs a table entry for
what it reads and writes, including the implicit stuff: `rep movsb` uses
`ecx`, `esi` and `edi`, `cpuid` writes four registers, `mul` writes
`edx`. If an entry is wrong, the compiler keeps a live value in a
register the asm just destroyed, and you get corruption that only shows
up when the optimizer happens to put something there. That's the worst kind
of bug, since it only sometimes happens.

GNU asm has similar failings. You can write the clobbers or forget them, and
the compiler doesn't check. MSVC puts the burden on the compiler writer
at the cost of optimization. Neither works: one needs a perfect
compiler, the other a perfect programmer, and either way a missed effect
shows up as a bug that only sometimes happens.

It's also bad for optimization. When the compiler isn't sure, it assumes
the worst, so an `__asm` block acts like a wall. Values in registers get
flushed before it and reloaded after, and it's hard to inline
a function that contains one. The GNU `increment` costs one `add`. The
MSVC one has to move `x` to the stack and back, since the compiler can't
prove the block doesn't care where `x` lives.

I assume this is why Microsoft dropped inline asm on x64. "Read the
instructions and guess" was already a source of bugs on x86, made
optimization harder, and forcing programmers to write more clobbers
probably wasn't a good enough DX to continue down this path.

For slate, this means the inference has to be pessimistic. An
instruction without an effects entry is assumed to clobber everything,
and a block that does something I can't model (like a `push` before a
stack-relative reference) is an error instead of a guess.

There's also some surprising syntax. If `arr` is an `int` array,
`arr[4]` inside MSVC assembly means a byte displacement of four, not
the fourth array element. `s.field` contributes the field's byte
offset. We resolve those into structured address operands rather than
trying to replace names in a string.

```text
  GNU asm                         MSVC asm
  template + constraints          instructions + C names
            |                         |
            v                         v
  decode operand contract         infer operand contract
            |                         |
            +------------+------------+
                         v
                  common assembly IR
                         |
                         v
                  Rust asm! lowering
```

The effects table includes implicit writes too. A one-operand `mul`
writes EDX:EAX. `call` can overwrite caller-saved registers. Writing
`al` needs a clobber for its containing register, not just a fictional
independent eight-bit register.

## What about 64-bit MSVC?

Since MSVC [doesn't support inline assembly on x64](https://learn.microsoft.com/en-us/cpp/assembler/inline/inline-assembler?view=msvc-170).
, thankfully we only have to deal with 32-bit asm. For 64-bit asm, you
need to either use intrinsics (recommended) or link your C code to
generated MASM code (far worse for slate to handle) so I've punted on
that until I at least get the 32-bit side off the ground.

## In Summary

Starting this off I thought inline asm would be just another subsystem,
but in working on slate, I'd have to say it's one of the hardest parts
of translating C because there's no standard (it's an extension, so gcc,
clang, msvc all act differently) and because they made such different
tradeoffs to craft their inline asm, and slate has to support all of it
(including you, x64 masm, but that's probably months from now), it's a
never-ending mess of bizarre bugs between gcc/clang/msvc, and requires
special casing for each of the compilers in a way most of the other
subsystems don't have to deal with (outside of compiler flags, which
I'll have to discuss how slate deals with another time).
