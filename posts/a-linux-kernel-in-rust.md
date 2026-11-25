---
title: "A Linux Kernel in Rust"
date: 2026-11-16T19:41:09-05:00
draft: false
---

I've been hearing clamors of bringing Rust to Linux. There's a whole Rust for
Linux initiative. Why not translate the whole kernel, especially since Slate can
translate C to Rust? (Spoiler alert: This took way longer than I expected)

## Starting Off

Since I had just gotten slate to translate CPython to Rust, I was fairly
confident. This couldn't take that long. In retrospect, this was way too naive.
Most of the projects slate translated (Sqlite, CPython, Lua, many others) were
all hosted, so they can lean on the OS. That means the C they exercise is
**much** (emphasis on the much) simpler than what the linux kernel deals with.

That being said, translating Linux was very productive because I found **a lot**
of bugs in Slate, and a lot of bugs + features I wouldn't have really thought
about.

## Optimism

The only way to make progress is try. So, I tried. My first baseline had 30000
errors and took 180GB of RAM to translate (I have 32GB, so needless to say my OS
killed the slate process).

I'll go through some of the interesting ones (imo) since they're illustrative of
the issues that make compiling a kernel much much worse than other C projects.

## `i` operand constant only valid after optimizations

This was one of the first ones I worked on, since ~12k functions had this issue.

First off, ask yourself, does setting the optimization flags (`-O0`, `-O1`,
`-O2`, `-O3`) change the semantic meaning of a C program? Should they affect
translated Rust code?

If you ask me, I'd say no. I was expecting to parse C, and then emit some Rust,
and then **ignore** all optimization flags. Why would C change behavior under
one optimization level and not another?

Take a look at this fixture:

```c
struct key { int enabled; };
struct key k1;
static inline __attribute__((always_inline)) int branch(struct key *key, _Bool likely) {
    asm goto("# %c0 %c1" : : "i"(&((char *)key)[likely]), "i"(likely) : : yes);
    return 0;
yes: return 1;
}
int f(void) { return branch(&k1, 1); }
```

What should the call to `k` return? A 0, right? Actually, it doesn't compile
under `-O0`:

```
error: impossible constraint in 'asm'
```

and it returns 0 when compiled at `-O1` or above:

```asm
"f":
        xor     eax, eax
        ret
        mov     eax, 1
        ret
"k1":
        .zero   4
```

The `i` constraint requires an immediate known at compile time, which without
optimizations is not possible, because the program has:

```c
struct key *key = &k1;
_Bool likely = 1;
```

To fill in:

```c
asm goto("# %c0 %c1"
    :
    : "i"(&((char *)key)[likely]), "i"(likely)
    :
    : yes);
```

However, after optimization, the compiler sees something like:

```c
asm goto("# %c0 %c1"
    :
    : "i"((char *)&k1 + 1), "i"(1)
    :
    : yes);
```

which allows the compiler to make the substitution. So, any C to Rust transpiler
needs to handle optimization levels, outside of just plain `__OPTIMIZE__` (the
preprocessor macro, so I changed slate to pass optimization levels just like the
target, flavor, and C standard, so the emitted rust could change based on
optimization.

## Properly handle `ebx` on i686

Rust doesn't allow you to use `rbx` as a register, since that's a scratch
register for Rust to use, on `x86_64`. The i686 version of that is `ebx`, so I
thought we needed extra handling for both. Totally incorrect. Actually, `esi` is
the one that's reserved, so I had to change my handling of inline assembly.

## Overloads

Slate didn't handle overloads, so:

```c
static void __attribute__((overloadable)) acquire(struct spinlock *l) {}
static void __attribute__((overloadable)) acquire(struct mutex *l) {}
```

Would cause a compiler error. Basically, `__attribute__((overloadable))` should
make these be "different" function names and then overload the name. Slate now
adds a `__$NUM` suffix to functions to do so.

## Pointer arithmetic in static initializers need to lower to `wrapping_offset`

In rust, if you call `.offset()` on a static initializer (which could be an
integer), the pointer arithmetic has to be in bounds. In C there's no such
guarantee; so:

This is totally fine:

```c
extern const int sysctl_vals[];
static void *one = (void *)&sysctl_vals[1];
```

But the rust equivalent would fail to translate. Just for static initializers
this needs to be wrapping offset.

## Add `-m16` and `-m32` flags

Since the linux kernel needs to boot from nothing, it also needs to handle
16-bit and 32-bit as well.

An x86_64 computer boots in 16-bit real mode, so gcc/clang have an `-m16` flag,
which basically takes the 32-bit target (i686-unknown-linux-gnu) and turns its
pointers to 16-bit. This is for running the firmware; then it boots into
protected mode, which is 32-bit, and has a corresponding `-m32` flag. Finally,
the kernel needs to boot into long-mode, which is the normal kernel path. So a
compiler that wants to compile a kernel for x86_64 needs to always handle 3
targets.

## Making Slate code no_std

Slate didn't support a no_std mode, so it couldn't translate the linux kernel.
To fix that up, a few changes were in order; change all the definitions emitted
from `std::` to `core::` (where possible) and then capture flags that state that
a file is supposed to be freestanding (`-ffreestanding`) or `-nostdinc` should
compile as `core` only. That means parsing those two flags and then threading it
through slate's parser. Wasn't too hard but something to do before continuing
on.

## Freestanding crates can't be `C-unwind`

Because of prior issues with POSIX thread cancellation in C, I made every extern
C-unwind. However, this doesn't work for freestanding crates. Thankfully, theres
`panic=immediate-abort` available as a rust flag, which deletes all panics
emission from code. As well, providing a panic handler that does nothing and
preventing freestanding code from emitting C-unwind let me continue on.

## Remove indirect function calls for builtins

Rust by default emits indirect function calls through the Global Offset Table
(GOT) when emitting code, so:

```c
struct pt_regs *regs, *eregs;
*regs = *eregs; // memmove
```

Would generate something like:

```asm
mov memmove@GOTPCREL(%rip), %r11
call __x86_indirect_thunk_r11
```

This is a mitigation for meltdown. The linux kernel's `objtool` will complain
about this, because some functions are labeled `.noinstr`, which means they
cannot be indirect calls.

This just requires `-Zplt=yes` be passed to a rust build, which causes the code
to be emitted directly:

```asm
call memmove
```

## Freestanding crates need to have `#![no_builtins]` set

Take a look at this redefinition of strlen:

```c
__attribute__((noinline)) static size_t count_bytes(const char *s) {
  const char *sc;
  for (sc = s; *sc != '\0'; ++sc)
    ;
  return sc - s;
}
size_t strlen(const char *s) { return count_bytes(s); }
```

When translating to rust, llvm's loop idiom recognition turned the loop in
count_bytes into `strlen`, since it recognizes this is a strlen call (it does
this for other things like popcount as well).

So, llvm would see something like:

```c
__attribute__((noinline)) static size_t count_bytes(const char *s) {
    return strlen(s);
}
size_t strlen(const char *s) { return count_bytes(s); }
```

And then the function would infinitely recurse. Whoops. This can be fixed by
disabling the specific instance, but rust provides `#![no_builtins]` for this.

## Handling `-fno-strict-overflow` properly

Take a look at this helper, which checks if `buf + size` has wrapped past the
end:

```c
__attribute__((noinline)) static int end_wraps(char *buf, unsigned long size) {
  char *end = buf + size;
  return end < buf;
}
```

In standard C, this is UB since we've wrapped past the end, however the kernel
relies on its compiler (Clang and GCC) to have wrapping arithmetic.

The translation slate had for `end` was:

```rust
let end: *mut i8 = unsafe { buf.add(size as usize) }
```

However, `add` requires that the pointer must stay in bounds or one byte past
its end. If not, rust considers this UB. Thus, LLVM actually decides to delete
the return branch:

```rust
let end = unsafe { buf.add(size); }
// this branch is deleted:
// if false {
    // overflow logic
// }
```

However, if you change this to `wrapping_add`, llvm will behave as the
equivalent C does, and not delete the branch.

## Handle all flags, log all unsupported flags

Since it's not possible to handle every single flag (we only want to handle
those that change codegen), after the `-fno-strict-overflow` check, I changed
Slate to just log if an unknown flag is parsed. That way, a user can verify if
the flag is required to keep behavior, or if it can be safely ignored.

## Getting a linux kernel in Rust

After these changes (and a whole lot more), I was able to get compiler errors
down to 0, build vmlinux in Rust, and knock out all of the objtool errors.
There's still lots more to do to verify (run through all of the kernel's test
suites), but seeing the kernel boot to busybox meant it was mission accomplished
for now. You can check it out for yourself at
[slate-linux](https://github.com/takashiidobe/slate-linux).

Slate can now translate freestanding code, with its first project being the
linux kernel. As far as I know, there's no automated C to Rust program that can
translate the kernel (correct me if I'm wrong). Of course, this is still the tip
of the iceberg, trying to translate the kernel required squashing a lot of bugs,
so there's still plenty to look at, but it's good to admire the view from the
summit.
