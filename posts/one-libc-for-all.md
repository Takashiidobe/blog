---
title: "One libc for all"
date: 2026-09-01T08:57:15-04:00
draft: false
---

I've been working on [Slate](https://github.com/takashiidobe/slate),
a C to Rust translator. Take a look at the previous post here:
[Translating long double to rust](./translating-long-double-to-rust.md).
Today's topic is why slate provides its own libc that it links to,
and why that's useful for a c to rust transpiler.

When I first started out on slate, I didn't link to a custom libc. Why
would you, you install a compiler, it's automatically pointed at the
libc you have configured, and you can start compiling. The compiler has
everything you need. This works for a single target setup. If you're
compiling code for only your target (I'm on x86_64-unknown-linux-gnu).
However, C and Rust are both easily cross compiled for other targets.

There are a series of preprocessor macros that are defined per target,
which can enable and disable code. For a very trivial example, here's
a program that prints differently based on if you're on x86_64 or not:

```c
#include <stdio.h>

int main() {
#if defined(__x86_64__)
    puts("hi from x86_64");
#else
    puts("hi from any other architecture");
#endif
}
```

When compiling the program, some C compilers like gcc and clang will
define the `__x86_64__` macro when compiling your code, setting it
only for x86_64 systems, so it's possible to test for it. Because the
preprocessor can only choose one block here, the actual programs that the
C compiler will see after preprocessing are either:

```c
#include <stdio.h>

int main() {
    puts("hi from x86_64");
}
```

Or:

```c
#include <stdio.h>

int main() {
    puts("hi from any other architecture");
}
```

This is fine and dandy. Rust also has a similar mechanism
(`#[cfg(...)]`) blocks that let us do the same thing, so this is
semantically the same program:

```rust
fn main() {
    if cfg!(target_arch = "x86_64") {
        println!("hi from x86_64");
    } else {
        println!("hi from any other architecture");
    }
}
```

Now the crux is that we want to take the C program and translate it to
Rust. How do we do that? The C preprocessor plays a cruel trick on us --
since it only preserves blocks that are enabled for you (either through
`-D...` or through the compiler, you can't actually see the full
program, you'll only see the program after preprocessing. So, we could
say translate to:

```rust
fn main() {
    println!("hi from x86_64");
    // or this: println!("hi from any other architecture");
}
```

But we'd have lost cross compilation.

What's even worse in a way is that this program is wrong -- on a
non-x86_64 architecture, you want to see `hi from any other
architecture`, but you'll see `hi from x86_64` regardless of what target
you compile for.

One half of the problem is how to splice the preprocessor blocks such
that we can recover the original program. That's for another time.
However, C also allows us to configure our build differently based on
different flags, which is really useful.

For an example here, I have a macro that I use for setting memory
alignment:

```c
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L
#define __aligned(X) [[aligned(X)]]
#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
#define __aligned(X) _Alignas(X)
#elif defined(__GNUC__) || defined(__clang__)
#define __aligned(X) __attribute__((aligned(X)))
#elif defined(_MSC_VER)
#define __aligned(X) __declspec(align(X))
#else
#define __aligned(X)
#endif
```

Different compilers and different versions of the c standard library
have different ways of expressing this concept. Since this was
non-standard until C11, MSVC and clang chose different ways to express
this concept. However, until C11, since this was not in the standard,
compilers didn't need to have a way to express it. In that case, aligned
is defined as an empty string.

This is an important part of C, and without support for this, you can
only support truly standard C that uses no architecture specific
features or compiler features. Thus, to translate C, Slate needs to
provide this faculty.

Thinking back to the start of this blog post though, our target only has
a standard library for our target. So slate can't rely on the user's
libc for platform code, and has to provide its own libc. To actually
compile a whole matrix of libc code, slate defines target specific
macros in its own libc:

```c

#if defined(__SLATE_ARCH_X86_64) + defined(__SLATE_ARCH_X86) +                 \
        defined(__SLATE_ARCH_AARCH64) + defined(__SLATE_ARCH_ARM) +            \
        defined(__SLATE_ARCH_RISCV64) + defined(__SLATE_ARCH_RISCV32) !=       \
#error "Slate requires one supported target architecture."
#endif
```

Which are passed at build time based on the target that's requested to
be cross compiled:

```rust
FixtureFlavor::Macos => &[
    "-D_SLATE_LIBC",
    "-D__SLATE_ARCH_AARCH64",
    "-D__SLATE_VENDOR_APPLE",
    "-D__SLATE_KERNEL_DARWIN",
    "-D__SLATE_PLATFORM_MACOS",
    "-D__SLATE_LIBC_DARWIN",
    "-D__SLATE_OBJ_MACHO",
    "-D__SLATE_WORDSIZE_64",
    "-D__SLATE_ENDIAN_LITTLE",
],
```

This allows slate's libc, libc-shim, to be compiled for different
targets and still show one consistent libc for rust externs to link to.

## the `strerror_r` incident

Here's a question for you, dear reader. What's the signature of
`strerror_r`?

```c
int strerror_r(int errnum, char *buf, size_t buflen);
```

or is it?

```c
char *strerror_r(int errnum, char *buf, size_t buflen);
```

The answer is it depends based on which libc you're using. The first
definition is the standard one, and the second one is the gnu extended
one.

This would be fine on systems with 32-bit pointers, but nowadays those
are rarer, we live in the 64-bit world. So these have different ABIs.
It's not really that bad except for the fact that `strerror_r` has
different behavior in the gnu version than it does for the standard one.

And so any C program translated to Rust on a glibc system vs a musl one
where the signatures agree will have diverging behavior, and any where
you compile on a 64-bit system will simply not recompile. Wonderful.

## `qsort_r` has different signatures

What's the signature of `qsort_r` in freebsd?

```c
void qsort_r(
    void *base,
    size_t nmemb,
    size_t size,
    void *thunk,
    int (*cmp)(void *, const void *, const void *)
);
```

or is it?

```c
void qsort_r(
    void *base,
    size_t nmemb,
    size_t size,
    int (*cmp)(const void *, const void *, void *),
    void *thunk
);
```

As you might expect the answer is both of them are valid. The first
version is the standard POSIX version, and the second one is the old BSD
version, which was different. Since the first version was standardized
in 2024, freebsd decided to do a swap. So if you were to compile on a
newer version of freebsd and send your transpiled code to an older version
(or vice versa), your code would be incorrect. C side this is fine
because the linker will choose the correct symbol, but the externs in
rust won't line up if translated through slate.

Both of these problems (and others) can be handled if you control the
libc itself -- you can link older versions of code for compatibility, or
choose the right version to match the target and use `#[cfg]`s to have
cross target and cross version code work just fine.
