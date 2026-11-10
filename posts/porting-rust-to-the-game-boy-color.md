---
title: "Porting Rust to the Game Boy Color"
date: 2026-11-09T16:41:29-05:00
draft: false
---

# Porting Rust to the Game Boy Color

As a youth, I was glued to my Game Boy, pouring countless hours into
playthroughs of pokemon blue. I had a playthrough using every starter
(charmander, squirtle, bulbasaur) and I wanted to see if I could make a
toolchain to write rust and get back assembly for the Game Boy to run through
the rgbds toolchain.

tl;dr: I recommend using [rust-gb](https://github.com/zlfn/rust-gb) and
[gbdk](https://github.com/gbdk-2020/gbdk-2020) for your retro programming fix,
since I'm not satisfied with the codegen on my project, but it was an amusing
exercise in getting a fairly high level language on a fairly old CPU.

## The Game Boy ISA:

Some people say the Game Boy Color's assembly is an Z80, Intel 8080, LR35902, or
an SM83. Whatever the architecture, it's an 8-bit computer with 7 general
purpose registers `a`, `b`, `c`, `d`, `e`, `h`, `l`, and a separate flags
register, `f`. `a` is the accumulator, which is special because it is the target
for a few other 16-bit ops. Every register other than `a` can be paired to
become a 16-bit register, so:

- `b` + `c` -> `bc`
- `d` + `e` -> `de`
- `h` + `l` -> `hl`

Otherwise, the Game Boy is a CISC, so it's meant to be written rather than
compiled to. I don't believe there were many people writing C and then compiling
to asm for game boy games.

There's a few groups of instructions supported like:

- Moves: `ld`, `ldh`, `push`, `pop`, `swap`
- Arithmetic: `add`, `adc`, `sub`, `sbc`, `and`, `xor`, `cp`, `inc`, `dec`
- Rotates: `rlca`, `rla`, `rrca`, `rra`, `rlc`, `rl`, `rrc`, `rr`, `sla`, `sra`
- Bit manip: `bit`, `res`, `set`
- Jumping: `jp`, `jr`, `call`, `ret`, `reti`,
- Misc: `nop`, `halt`, `stop`, `rst`

Note there's no multiply or divide, but thankfully there's adding with carry and
subbing with carry (`adc` + `sbc`) which ease use of 16-bit registers. Also of
note, there are no floating point numbers. Lots of operations in rust use 32-bit
ops (`i32`, `u32`, `f32`), and we also need a word size here in Rust, and as
most other compilers set it to 16-bit to access the 32Kb of ROM memory. And that
doesn't even address the elephant in the room, how are we going to deal with
`i128` and `u128`?

## The architecture of sangoku

I decided to call my project `sangoku`, because the game boy's chip is sometimes
called the `lr35902`. In Japanese, san -> 3, go -> 5, and ku -> 9, so it's
basically 359 read out individually as numbers. Crafty name aside, I needed a
way to turn Rust to a game boy ROM.

I decided to make a fork of `rust` to add support for a "z80" backend, and then
a fork of `rustc_codegen_cranelift`, and `cranelift`, to hook everything
together. Basically the pieces go:

`rustc` (frontend) -> `rustc_codegen_cranelift` (middle end) -> `cranelift`
(backend/optimizations) -> LR35902 asm -> `rgbasm`/`rgblink`/`rgbfix`.

Rustc didn't need much in terms of changes, just adding in the new target. More
changes have to go in `rustc_codegen_cranelift` (I'll refer to this as
`cg_clif`), like disabling C variadics, lowering traps, and disabling float
builtins. `Cranelift` houses most of the changes, like making registers 8-bit in
regalloc (cranelift targets 64-bit targets), making a specific ABI, marking
which registers are clobbered or not, and then emitting assembly instead of a
binary (which cranelift does by default), and then filling out all the
information for the LR35902, and optimizations for the backend itself. Most of
the changes go here.

## Compiling Core

My goal was to make it to `core`. Rust basically has 4 levels of platforms:
`no_core`, `core`, `alloc`, and `std`.

`no_core` is nightly only and not as well known as the others, but it basically
defines nothing, where you have to implement basic traits like `Copy`, `Sized`,
and operators like `+` or other language items. This is barely support at all,
but it's a sanity check that the toolchain works end to end.

`core` defines the language itself. All the goodies like `i64`, `bool`,
`Option`, `&str`, `Result`, `Iterator`, traits, stuff like that come here. You
can't alloc memory though, so `Box`, `Vec`, `String` and friends are out of
scope, but this is a fairly decent bare metal target; it's about equivalent to
`-ffreestanding` for a C compiler.

`alloc` was a possible stretch goal, although with 32KB of ROM, it might be hard
to cram everything in without the runtime taking up too much space, since we
need an allocator and to support lots of larger types.

`std` isn't possible, since we don't have an OS to run on, so `alloc` is about
as far as my ambitions can go on the Game Boy.

## Compiling to core

Let's talk about what we need for core: first, we need to lower `i8` and `i16`.
Those are doable since we have registers for that, and most of the work is in
mapping each arithmetic operation to a suitable asm op. But we don't have
multiply or divide!

This is where libcalls (*lib*rary _calls_) come in. Libcalls are software based
routines that shim operations your target doesn't have hardware operations for.
In our case, that means we need to implement our own multiply; we can do this by
adding and shifting. For `i8` multiplication:

```asm
;  b and c are operands, result goes in a
__gbc_mul8::
    ld d, 8          ; bit counter
    xor a            ; acc = 0
.loop
    add a, a         ; acc <<= 1
    sla c            ; shift the multiplier's top bit into carry
    jr nc, .skip     ; bit was 0: nothing to add
    add b            ; bit was 1: acc += multiplicand
.skip
    dec d            ; decrement d by 1
    jr nz, .loop     ; if zero flag is not set, jump back to loop
    ret              ; return (result in a)
```

For `i8` division:

```asm
__gbc_div8_core::
    ld a, c          ; move c to a
    or a             ; bitwise or a
    jr nz, .nonzero  ; jump to loop if zero flag is not set
    rst $10          ; divisor == 0 ? trap (div by zero)
.nonzero
    xor a            ; remainder = 0
    ld e, 8          ; load 8 into e
.loop
    sla b            ; top bit of the dividend/quotient register → carry
    rla              ; ...and into the remainder (remainder = rem*2 + bit)
    cp c             ; remainder >= divisor ?
    jr c, .next      ; no: quotient bit stays 0
    sub c            ; yes: remainder -= divisor
    inc b            ; ...and set the quotient bit (B's low bit was just vacated by sla)
.next
    dec e            ; decrement e
    jr nz, .loop     ; jump back to loop if zero flag is not set
    ret              ; return (result in a)
```

Next up, we need to implement wider widths; for `i8` and `i16`, we can implement
all the arithmetic ops since we have software mul and divide, but we also need
to handle `i32`, which would require stitching together 4 free registers. But
`i64` stops, since we have 7 registers that have 8-bits each, so we only have 56
bits of register, which can't express a 64-bit type. That blocks us.

To do that, we do something called `legalization`, which turns unsupported data
types (like `i64`) into some form the target hardware can understand. In our
case, that means in `cranelift`, turning an `i64` into 2 `i32`s, and stitching
those together. For an `i128`, we split into 4 `i32`s (this required a bit of a
change since cranelift only targets 64-bit targets, so there's only a need to
split `i128` into 2 64-bit registers, so I made a change to build a 128-bit type
out of 4 32-bit registers. Float types also needed support; there is no hardware
float support, so the change was to treat any float as an int of the same type,
and then direct its lowering ops to similar libcalls, to emulate floats in
software.

There's a lot of other busywork (implementing casts between types) and also
implementing memory libcalls (like `memcpy`, `memmove`, etc). After implementing
all of the types properly, rust itself can compile core!

## Core compiled

I decided to compile a test program that basically called `sort_unstable` and
then `println!` to sort and print a list of integers. `sort_unstable` doesn't
require memory allocation, so it's on core, and neither does printing.

My program was `202KB`. Each ROM of the Game boy is 32kb at max. Ouch. I had 3
problems:

1. `sort_unstable` can panic, where it calls `slice_index_fail` and
   `new_display`, so `sort_unstable` pulls in both formatting code and panic
   handling code. At this point that was about `150KB` of code, far exceeding my
   limit.
2. I implemented almost every operation in cranelift with inlining, only using
   libcalls where absolutely necessary (like multiply, divide, or floats). This
   wasn't going to fly, because trying to access say a `u64` with just 8-bit
   registers spills and emits a lot of instructions. Even one access could
   easily balloon to 1KB of code.
3. I needed better debugging.

Lots of things in rust can panic; indexing, `slice::swap`, overflow checks,
`unwrap` each call `panic_bounds_check` / `slice_index_fail` / `panic_fmt`,
which build `fmt::Arguments` and call `fmt::write`. Therefore, **any** method
that can panic pulls in both formatting and panicking machinery. For the game
boy, this was about `22kb` of code. For reference, the code itself was `2kb`.

By setting `panic=immediate-abort`, panics turn into a trap instruction
(`rst 10h`), which split the binary size by basically half immediately, since
panic handling code isn't generated(`202kb` -> `115kb`). After also applying
`Zmir-strip-debuginfo=all-locals`, the formatting code was also removed.

As a sidenote, it's possible to nudge the compiler to delete panicking code by
using `if let`, or `iter()`, or some higher level construct that doesn't panic.
Since the compiler knows panicking isn't possible, it doesn't emitting the
panicking or formatting machinery, but this is a bad default, especially for a
memory constrained ROM.

### Unicode lookups

Next up was to try out strings; I did one call to `to_lowercase` on a non-ASCII
character. That was already `47KB`, well over the `32KB` limit, with ~42KB
coming from lookups. Groan.

In Rust, `to_lowercase` is unicode-aware. Since there's not necessarily any
rhyme or reason to lowercasing or uppercasing a unicode character, the best way
(and the way Rust does it) is by employing a lookup table. The tables themselves
were about `11KB` on the gameboy, and they required `bitset_search`, and
`skip_search` (skiplist search) as well as a `u64::rotate_left`. Most of the
overhead came from these. Only way around it is not using these methods, maybe
by adding custom lints for the target. On the flip side, this allowed some
optimizations, like optimizing `c >> 16` from 16 `srl`s to whole-byte `ushr`,
handling `i32`s as `i16`s or `i8`s when possible, and optimizing binary search.

## Alloc, the oasis

Alloc in general doesn't need much else other than an allocator. A simple bump
allocator (there's no OS) suffices, but trying to compile programs that used the
heap had the same issue as core did, a basic program that used a Vec was `64kb`.
Since Rust is heavily monomorphic, it was pretty easy to have to make many
copies of `Vec<T>`, which push memory cost up considerably. `Box`, on the other
hand, is much smaller.

Instead, a custom Vec type, `FixedVec<T, N>` is much smaller; about 1.8KB. Still
fairly large, but it's a little better than the about 13KB of overhead that a
Vec had.

## Optimization ad nauseam, ad infinitum, ad mortem

After being able to compile to alloc, the rest of the work is optimization. I
look at a fixture/code to check if the code could be better, and then try to
target optimizations. Most of the higher level ones are getting rid of inlining,
and then trying to optimize for size vs. speed. For now, most work involves
ripping out inlining for ops that aren't easily supported by hardware (i.e.
32/64/128 bit ops) and then moving them out to libcalls. One arithmetic op on an
i128 ranges from 1.5KB to 5KB, so inlining that would basically overrun the ROM
capacity in about one line.

Some fixes are config based: `-Zinline-mir=yes` in cranelift handles inlining
MIR away, which can cut binary size by half or more, and splitting out the
runtime itself (which was a bunch of libcalls in one file) into an
implementation per file also dropped size a lot (rgblink doesn't do garbage
collection to delete unused sections).

Another interesting to note, compilers have say `-s/-z` for size, and then
`-O 1 | -O2 | -O3` for optimization options. I generally always used `-O3` for
release (or `-O2` in C), and very rarely used `-s`. However, since the LR35902
has such little space, one idea I had was to provide a space optimized and a
time optimized version of a function. That way, if the user provides `-s/-z`,
they can get smaller functions even in libcall heavy code, and for the
optimization flags, they can get a libcall that's more tilted towards speed.

One example is `memset`:

Optimized for speed:

```asm
SECTION "memset", ROM0

__gbc_memset::
    push bc
    ld d, a
    ld hl, sp + 7
    ld a, [hli]
    ld h, [hl]
    ld l, a
    push hl
    ld h, c
    ld l, b
    pop bc
    ld a, d
    srl b
    rr c
    jr nc, .skip_one
    ld [hli], a
.skip_one:
    srl b
    rr c
    inc b
    inc c
    jr nc, .test
    jr .fill_two
.fill_four:
    ld [hli], a
    ld [hli], a
.fill_two:
    ld [hli], a
    ld [hli], a
.test:
    dec c
    jr nz, .fill_four
    dec b
    jr nz, .fill_four
.done:
    pop bc
    ld a, b
    ld b, c
    ret
```

Optimized for size:

```asm
SECTION "memset", ROM0

__gbc_memset::
    push bc
    ld d, a
    ld a, b
    ld b, c
    ld c, a
    ld hl, sp + 7
    ld a, [hli]
    ld h, [hl]
    ld l, a
.loop:
    ld a, h
    or l
    jr z, .done
    ld a, d
    ld [bc], a
    inc bc
    dec hl
    jr .loop
.done:
    pop bc
    ld a, b
    ld b, c
    ret
```

The size optimized version is 24 bytes, the speed optimized version is 43 bytes,
so speed optimized is about 2x as large.

The size optimized version sets bytes one by one in a loop, whereas the speed
version unrolls the loop to a factor of 4 and then fills in a loop.

There's more overhead in the speed optimized version (about 100 cycles), but
each byte setted takes about 12 cycles. For the size optimized version, each
byte is filled in 56 cycles, so for very small memset calls, the size optimized
version is **always** better, but for large byte arrays, the speed optimized
version approaches 56/12x faster (4.6x). It's fairly unlikely that you'll want
to set a large buffer at runtime, but even a 16-byte buffer is about 2.5x faster
for the speed optimized version.

### Optimizing Codegen (for dec r)

For an 8-bit register, `n -= 1` on it looked like:

```asm
ld b, 1
ld a, ..        ; n
sub b
```

But this can obviously be:

```asm
dec r
```

To do this, this required a new instruction in inst.isle:

```isle
(IncDec8 (dst WritableReg) (src Reg) (decrement bool))
```

And then an arm to implement it in lowering:

```txt
if iadd or isub, and type = i8,
    check whether or not the instruction is an inc/dec by 1
    then, call our new helper
```

Encoding:

```asm
IncDec8: put1((if dec 0x05 else 0x04 | (hw_enc(dst) << 3)))
```

Then labelling in regalloc to make sure that `dst` and `src` get the same reg.

## How much worse than C is Sangoku's Rust?

Pretty bad, actually. Here are some examples byte sizes:

| prog   | Sangoku |  SDCC |
| ------ | ------: | ----: |
| empty  |      95 |     2 |
| hello  |   3,893 |    67 |
| primes |   9,533 |   355 |
| sort   |  14,849 |   613 |
| heap   |  24,975 | 2,000 |

On a large program there's about 10x overhead, on some smaller programs, 15x+
overhead. SDCC has an advantage in that it compiles C, and has been around for a
while, but Sangoku is quite far from usable.

## Rust on Anything?

Given the whole rewrite it in rust crowd wants everything rewritten in rust, can
you write rust on the Game Boy? Probably, but at least this project would need a
few months of work before it would be anywhere near comparable to the titans of
gbdk or rgbasm, but that makes sense, they've been around for years. It might be
possible but the task is sisyphean, there is so much to optimize to get anywhere
near close to a good toolchain.

## Rust is still pretty cool

Here's the start of the surfing track from Pokemon Red/Blue: This is all in
core, and you can use most of the language OOB.

```rust
pub const TEMPO: u8 = 160;
pub const WAVE: [u8; 16] = [
    0x02, 0x46, 0x8a, 0xce, 0xff, 0xfe, 0xed, 0xdc, 0xcb, 0xa9, 0x87, 0x65, 0x44, 0x33, 0x22, 0x11,
];

use Event::*;
use sangoku_audio::Event;
use sangoku_audio::Note::{A, B, C, CSharp, D, DSharp, E, FSharp, GSharp};

pub static CH1: &[Event] = &[
    Duty(3),
    Vibrato(12, 3, 4),
    PerfectPitch,
    NoteType(12, 11, 5),
    Rest(6),
    Octave(2),
    // ...
];
```

Compare that to the original (this is from pret/pokered):

```asm
Music_Surfing_Ch1::
	tempo 160
	volume 7, 7
	duty_cycle 3
	vibrato 12, 3, 4
	toggle_perfect_pitch
	note_type 12, 11, 5
	rest 6
	octave 2
```

You get some nice abstraction. Not so bad. I'll have to keep reading the book I
bought to learn more about the GBC, Game Boy Coding Adventure, and hopefully as
I chip through the compiler, maybe I can even write some parts in rust without
overruning my ROM.
