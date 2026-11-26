---
title: "Translating C to Multi Target Rust"
date: 2026-11-25T11:18:04-05:00
draft: false
---

More discussion on [Slate](https://github.com/takashiidobe/slate), a C to Rust
translator, this time about translating projects that support multiple platforms
and features.

Last post, we discussed porting an x86_64 build of the linux kernel from C to
Rust. That of course brings up a follow-up question: the linux kernel is built
for many different targets, not just what I built it for, which is
x86_64-unknown-linux-gnu. Wouldn't it be nice if we could translate multi-target
C to multi-target Rust? (note: I'll use platform/target interchangeably)

## The problem

C is somewhat cross-platform. Some of the types, say `long` vary by your target.
As a unix-brained 64-bit buffoon (like me), you'd probably think `long` is
64-bits. However, the C standard actually doesn't say anything like "long must
be 64-bits". The standard says it must be at least 32-bits wide, and at least as
large as int. Which means `32 <= sizeof(long)`. 64-bits is certainly larger than
32 bits. But we're missing the biggest and bluest OS of them all, Windows. MSVC
(windows' native C compiler toolchain) defines longs to be 32-bits. To handle
this, a cross-platform libc implementation would have to typedef long based on
the compiled target.

That might look like this:

```c
#if defined(_WIN32)
    typedef signed long   int32_t;
    typedef unsigned long uint32_t;
#elif (defined(__APPLE__) || defined(__linux__)) && defined(__LP64__)
    typedef signed long   int64_t;
    typedef unsigned long uint64_t;
#else
    #error "any other target is out of scope for this blogware example"
#endif
```

And then depending on your compiler + platform, the definition of `long` will be
set up properly, because it'll either be a compiler error or defined differently
per platform.

### Macros are not enough

Preprocessor macros are fine but there are a lot of things you may want to
express in a cross-platform C project that are either painful to do purely in C
or impossible. This method works fine for static configuration (there is a macro
defined if the compiler is clang, or gcc, the POSIX standard, and many others),
but most projects need something more dynamic to deal with cross-platform
compilation for dependencies.

Instead of asking high-level queries like "did the user compile with clang, and
is this OS linux, and is this 32-bit or 64-bit", you really want to ask "can I
do X" in an open world. This is why lots of C projects use `autotools`, which
leads to the classic `make configure` `./configure`, `make install` dance that
building C projects from source entails. For example, you may want to know where
the user's `openssl` is. This can't be exposed by the compiler (are they really
supposed to predefine every possible query a user may want?) so autotools lets
you write small C programs, and then running `./configure` will compile them and
return a result that you can use in your build scripts. This uses the C
preprocessor as a build system, but separates concerns and extends C so you can
have both user-defined feature flags much easier, rather than being tied to the
fixed set that your compiler ships.

## Rust's Features

Rust has a similar "feature" which it calls features. You enable these a few
different ways, and there are a few different types:

1. Target cfgs (which narrow down information about the platform the code will
   run on, based on --target passed in, like `#[cfg(target_os = "linux")]`)
2. CPU target cfgs (`#[cfg(target_feature = "avx2"]` which let you target
3. Runtime feature detection: `if is_x86_feature_detected!("avx2")` lets you
   query the cpu that the code is running on, so both make it into the binary
4. User features: `#cfg(feature = "my_feature")]` to conditionally compile some
   parts of the application based on what the user wants set.

This basically lets us handle C features and roughly translate them into Rust
features, except for one thing in C. For example, in C's preprocessor you can
use relops for feature queries:

```c
#if __STDC_VERSION__ >= 201112L
    // C11 or later
#elif __STDC_VERSION__ >= 201712L
    // C17 or later
#endif
```

Because of this, you're allowed to express any arbitrary integer, which in rust
would be like:

```toml
[features]
c11_or_later = [] # deps go in here
```

Which converts the relops to a simple binary (yes/no) query.

So for translating features from C to Rust there's two parts:

1. Come up with some static list of macros, like `__linux__`, and define those
   for each relevant target.
2. Somehow translate "dynamic" features, those defined by say autotools as
   (`-D...` when building) into rust features, and then handle those.

Let's get into it.

## Getting Compile Commands

In C, every `.c` file that is compiled as an independent unit is called a
translation unit. Therefore, each "file" of input `.c` can be compiled with
different compiler flags (this is fairly common if say you want to optimize some
parts of your build but not others), or you have third party files you want to
build that use different compiler flags than you do.

We need some way to gather those and pass them to our slate for translation.
Thankfully, there's already a fairly common format for this called
`compile_commands.json`. Tools like cmake can emit this format oob, but for say
`make`, which cannot, you can use a tool like `bear` to turn your build commands
into this format.

```json
[
    {
      "directory": "/home/takashi/c-corpus/zlib/build-clang",
      "command": "/usr/bin/clang -DHAVE_HIDDEN -DNO_FSEEKO -DZLIB_BUILD -DZLIB_DLL -D_LARGEFILE64_SOURCE=1 -I/home/takashi/c-corpus/zlib/build-clang -I/home/takashi/c-corpus/zlib -O3 -DNDEBUG -fPIC -o CMakeFiles/zlib.dir/adler32.c.o -c /home/takashi/c-corpus/zlib/adler32.c",
      "file": "/home/takashi/c-corpus/zlib/adler32.c",
      "output": "/home/takashi/c-corpus/zlib/build-clang/CMakeFiles/zlib.dir/adler32.c.o"
    },
    ...
]
```

You'll notice it shows the compiler (the compiler name as the first arg) and
then all of its args, and then the file to compile (adler32.c). This repeats for
all the translation units required to build the final artifact, `zlib` itself in
this case.

Now that we have the compiler's invocation, we now need to parse it into a
structured format, and then turn each `-D` into a feature flag that can be set
for a given build (for my computer, apparently autotools has found out my
computer can set `HAVE_HIDDEN`, `NO_FSEEKO`, `ZLIB_BUILD`,
`_LARGEFILE64_SOURCE`, and `NDEBUG`).

It's possible to read each `-D` argument itself and then use these to seed list
of rust features, but you'll notice some of these aren't really useful features
for a translation to have. For example, `HAVE_HIDDEN` means my C compiler
supports `__attribute__((visibility("hidden")))`. That's great for a C
translation (since that changes how C code should be viewed) but since slate can
parse C code from gcc, clang and msvc, it doesn't make sense to pass this C
capability onto the rust (slate assumes you're using latest nightly always, so
it's not mired by having to support older rust toolchains).

Because of this, for a cross platform build, you'll want to manually provide the
list of "meaningful" (however you define it) features, ignoring stuff like
`debug` or `fseekno`, or `largefile64`. Slate asks that you do this manually and
create a cross platform build by providing a key-value pair of
`target = compile_commands.json` file, and then manually adding a key-value
mapping of feature_name to the c preprocessor macro it corresponds to (because
in C, features macros are normally SCREAMING_SNAKE_CASE'd and in rust they have
to be kebab-case'd.

## Static features

Now that the harder side is done, let's talk about the list of static macros
that `slate` has to use, e.g. set `__linux__` for a linux build. Thankfully it
is much easier than the dynamic features -- each compiler "sets" a list of
macros based on the target it's compiling for. You can query clang for its
`#define` directives like so: `clang -dM -E`. This prints out all of the defines
for a given target. So for each (compiler, target) pairing, I print out its
defines, so slate can properly "emulate" the compiler, even down to its defines.
This lets a user compiling C for their platform get the same result for their
rust.

## Jokers to the left of me, clowns to the right

Given this is the punchline of this blog post, I have to let you down here. It's
actually not that easy to translate cross platform Rust. We have the static
features, we have the dynamic features, but if you think about the number of
features and how they can interact, you're faced with a stark realization.

Let's look at an example with two features:

```c
#if defined(FEATURE_1)
   #if defined(FEATURE_2)
    // feature 1 and feature 2 are defined
   #else
    // only feature 1 is defined
   #endif
#elif defined(FEATURE_2)
    // only feature 2 is defined
#endif
// neither feature 1 nor feature 2 are defined
```

There are 2 possible features, and let's say both are boolean flags. Since we
don't care about ordering, there are 4 possible results:

`(true, true), (true, false), (false, true), (false, false)`

These are all the ways to fill an N-tuple with distinct booleans. That's right,
that's `2^N` for `N` feature flags.

I set 9 feature flags for my `zlib` build. `2^N` means each TU might have to be
translated up to 512 times. Oh yeah, and on top of that, I decided to do a
16-target build, because slate supports 16-targets so I figured why not. Each
target could compile up to 512 times, so a TU that uses all 9 of the defined
features could be compiled up to `2^(9 + 4)` or 8192 times. This is the actual
big problem, because feature flags simply require `2^N` translations of the same
TU at worst case. Since a feature set the user asks for is probably going to be
"the minimal set that makes sense", every feature is going show up in the code,
so it's impossible to even avoid the worst-case either.

Another gut punch? We have to stitch together each translation as well. For a
zlib file that's translated 8192 times, you'll have 8192 versions of it (this
does happen for some of zlib's files). Imagine a file that's 1000 loc. Naively,
you can wrap each file in a `#[cfg]` by target and feature flags defined. But
that also means you either have ~8000 copies of the same file or an 8M loc file
for the same C. We'll have to do better than this.

## Now what

I could give up. C2Rust doesn't have an equivalent feature. But I wanted to
write another blog post that no one will read, just like how I wanted to
translate the linux kernel to Rust (that no one will use). Let's start with the
combinational explosion issue by using a sacred technique programmers have
always used when faced with unsatisfied product managers and users.

PEBKAC: Problem exists between keyboard and chair. Blame the user. At worst case
you can never avoid the exponential amount of compiles required per target and
per feature. As long as the user is informed that each feature they add makes
compile times exponentially slower, they probably won't add too many. Zlib has
hundreds of `configure` checks, but only a few of them really matter to the
translated Rust. Most projects are fairly similar. In fact, I chose zlib
explicitly because last year, a project called
[`Hayroll`](https://dl.acm.org/doi/10.1145/3808276) used it as the "final boss"
in their study. However, the authors only decided to transpile and recover
macros from zlib with 5 configuration flags, because runtime increases
exponentially.

There are alternatives to blaming the user that I did explore. One way is to
"cache" compiled areas, and so if you hit the same area and know the code
emitted would be the same, you can return the cached area. However, this
requires a lot of caching, and in worst case, you can double your memory usage.

If you have a compile commands where every region is unique, you'll always add
to your cache, and you will never find the cache useful because each region has
no overlap. This approximately doubles your memory usage, and so means you can
translate about half as much code before OOMing. The increased memory pressure
also makes the compiler run so much slower, so the worst case becomes worse. On
best case, it does cut compiles significantly, but the algorithm is hard to get
right. Since slate translates TUs in parallel, this also requires multithreaded
synchronization.

## Merging cfgs

The other issue is also pressing. Each "translation" of the file is "unique" in
some way, but most of its output is overlapping in some way. The problem is that
the overlap isn't mergeable at first glance:

```rust
#[cfg(target = "x86_64-pc-windows-msvc")]
let x: u32 = 5;
#[cfg(target = "x86_64-unknown-linux-gnu")]
let x: u64 = 5;
```

We'd love to merge these two, but they're different types so Rust won't let us.
If only we knew a bit more information, like that the original program was:

```c
long x = 5;
```

This is where slate's own parser earns its keep. Since we own the IR, we can tag
each IR node (in this case a var decl) with its "C" type as well as its "Rust"
type. We need the rust type (`u32/u64`) to emit the right rust based on target,
but the C type lets us do something nice:

```rust
let x: long = 5; // why not do this (this deletes the cfg too)
```

Where we smuggle the definition into a helper library? (in this case it would be
libc).

```rust
#[cfg(target = "x86_64-pc-windows-msvc")]
type long = u32;
#[cfg(target = "x86_64-unknown-linux-gnu")]
type long = u64;
```

Many cases happen in real codebases where the type is the same, but the actual
semantics of the type differ by target. By hiding that behind a support crate,
we can recover back the original C source code and also delete a bunch of cfgs
while we're at it.

## Recovering macros

I'm sure you can think of another issue as well. Macros! The C-preprocessor does
textual substitution of macros before parsing. If you use something like
`clang-ast` to build your C to Rust tool, preprocessor macros aren't recoverable
out of the box (I assume you can write a libclang plugin to hook into
preprocessing in clang), but this is tricky, requires tracking llvm, and making
sure your users set up the plugin properly, can compile it, and their clang is
compatible. This is all a big headache, and so C2Rust doesn't recover macros
oob. (This is also why hayroll exists, because it's trying to recover C
preprocessor output after a pass that has "destroyed" it). (This is also why
C2Rust doesn't preserve comments, because clang doesn't do that OOB as well).

Thankfully, because slate has its own parser stack, we can mark macros
deterministically just as slate can comments. If slate finds code that came from
a macro, instead of inlining it (as preprocessing would do) at the callsite,
(which can create a lot of bloat if a large macro is inlined often), we can turn
it into a `macro_rules!` and then call it as a macro.

Let's take this from zlib's adler.c:

```c
#ifdef NO_DIVIDE
// blogware: all of our targets have hardware divide so we ignore this
// complicated branch
#else
    #define MOD(a) a %= BASE
    #define MOD28(a) a %= BASE
    #define MOD63(a) a %= BASE
#endif
```

Slate will recover MOD63 as a macro (note this has an unnecessary temp, it could
just say `a %= 65521` like the C does):

```rust
#[cfg(all(target_pointer_width = "64", unix))]
macro_rules! MOD63 {
    ($a:expr) => {
        let __v: off_t = $a;
        let __v2: off_t = __v % 65521;
        $a = __v2;
    };
}

#[cfg(all(target_pointer_width = "32", unix))]
macro_rules! MOD63 {
    ($a:expr) => {
        let __v: off_t = $a;
        let __v2: off_t = ((__v as c_ulong) % 65521) as off_t;
        $a = __v2;
    };
}
```

So we can compare its use:

```c
local uLong adler32_combine_(uLong adler1, uLong adler2, z_off64_t len2) {
    unsigned long sum1;
    unsigned long sum2;
    unsigned rem;

    /* for negative len, return invalid adler32 as a clue for debugging */
    if (len2 < 0)
        return 0xffffffffUL;

    /* the derivation of this formula is left as an exercise for the reader */
    MOD63(len2);                /* assumes len2 >= 0 */
    rem = (unsigned)len2;
    sum1 = adler1 & 0xffff;
    sum2 = rem * sum1;
    MOD(sum2);
    sum1 += (adler2 & 0xffff) + BASE - 1;
    sum2 += ((adler1 >> 16) & 0xffff) + ((adler2 >> 16) & 0xffff) + BASE - rem;
    if (sum1 >= BASE) sum1 -= BASE;
    if (sum1 >= BASE) sum1 -= BASE;
    if (sum2 >= ((unsigned long)BASE << 1)) sum2 -= ((unsigned long)BASE << 1);
    if (sum2 >= BASE) sum2 -= BASE;
    return sum1 | (sum2 << 16);
}
```

To what the slate translated version looks like:

```rust
fn adler32_combine_(
    adler1: c_ulong,
    adler2: c_ulong,
    mut len2: __SlateHoist_adler32_combine_,
) -> c_ulong {
    let mut sum1: c_ulong = 0;
    let mut sum2: c_ulong = 0;
    let mut rem: u32 = 0;
    // for negative len, return invalid adler32 as a clue for debugging
    if len2 < 0 {
        return 4294967295;
    }
    // the derivation of this formula is left as an exercise for the reader
    MOD63!(len2); // assumes len2 >= 0
    rem = len2 as u32;
    sum1 = adler1 & 65535;
    sum2 = (rem as c_ulong).wrapping_mul(sum1);
    MOD!(sum2);
    sum1 = sum1.wrapping_add((adler2 & 65535).wrapping_add(65521).wrapping_sub(1));
    sum2 = sum2.wrapping_add(
        (adler1 >> 16i32 & 65535)
            .wrapping_add(adler2 >> 16i32 & 65535)
            .wrapping_add(65521)
            .wrapping_sub(rem as c_ulong),
    );
    if sum1 >= 65521 {
        sum1 = sum1.wrapping_sub(65521);
    }
    if sum1 >= 65521 {
        sum1 = sum1.wrapping_sub(65521);
    }
    if sum2 >= (131042 as c_ulong) {
        sum2 = sum2.wrapping_sub((131042 as c_ulong));
    }
    if sum2 >= 65521 {
        sum2 = sum2.wrapping_sub(65521);
    }
    sum1 | sum2 << 16i32
}
```

Since we've recovered the macro, the code reads exactly the same as the C
version.

## Actually implementing it

The one thing I didn't mention is that this requires some "magic" or constraint
solving. We basically have a set of targets, and a set of booleans, and logic
(any, all, not). For example, the line:

```rust
#[cfg(all(target_pointer_width = "64", unix))]
```

Is actually a simplification of all unix targets (say `x86_64-unknown-linux-gnu`
and `aarch64-unknown-linux-gnu`, the android, freebsd, and mac versions, of
which there are 8) and then finding the minimal set using target_pointer_width,
target_os, and other properties that can fit under the same cfg and then
collapsing them all.

If you don't do this, you'll get 8 different versions of the same code still, so
the decrease in code emitted will be a lot less.

## Picking the fruit

With all that in mind, what does that let us do?

Let's start off with lines of code. A translation of zlib for my computer using
C2Rust is about 25,000 LOC (25251 loc of rust to be exact, but this will vary
based on the version of zlib and c2rust and your target). Assume I translated
zlib with C2Rust for 16 targets, this would be `25000 * 16` or about 400k loc.

Zlib, `./configure`'d for my computer is 23114 loc (about 10k lines of C, the
rest being header files). So C2Rust does pretty well to keep a reasonable amount
of code here. However, this is for one target and no features (i.e. the default
features are set and baked into your build).

A single target, single feature translation of zlib with slate is approximately
22k loc (roughly the same as C2Rust). However, a 16-target, 9-feature enabled
build is 34771 loc. The [code](http://github.com/takashiidobe/slate-zlib) is
also pretty readable imo (I'm biased I know).

Talking about performance, Hayroll mentioned zlib is about 11,702 lines of code,
and they took about 2s per 1k lines of code per thread to recover preprocessor
macros -- that means about 25s or so of total translation time for a 5 feature
build. Slate runs multithreaded (so it's not apples to oranges), and takes about
30s to translate 16-targets and 9 features. Given the exponential factor being
about 2^8 more (2^4 more time for targets and 2^4 for more features), Slate is
roughly doing 256x more work in roughly the same time (I have no idea what
computer they benchmarked on, but since they stated single-threaded and I have
12 cores, lets say slate is doing 256x more work, but has ~16x (simplifies the
math) more firepower, so it's about 16x faster (these are all back of the
envelope numbers).

For correctness, since slate has its own parser stack, so it can recover every
macro and track it through the transpilation process; that means either slate
translates C code properly, or excluding parser bugs (or a bug in the merge
subsystem of slate), slate recovers preprocessor macros purely
deterministically. Afaik Slate is the only C to Rust translator that has this
feature; other systems I saw either use LLMs, cannot recover all preprocessor
macros always (hayroll), or ignore them (c2rust).
