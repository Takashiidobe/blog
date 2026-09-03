---
title: "Translating Intrinsics"
date: 2026-09-03T08:54:06-04:00
draft: false
---

This is part of [Slate](https://github.com/takashiidobe/slate),
a C to Rust translator! Take a look at the previous post here:
[Switch to Match](./switch-to-match.md).

Today's topic is about intrinsics. Intrinsics are functions supplied by
a compiler that map to hardware instructions. These fall into two
buckets:

1. `builtins`

For example, the function `__builtin_popcount(unsigned int)` for GCC
and Clang provide a population count function. These lower to special
"compiler instructions", e.g. `llvm.ctpop` for clang that are fast
pathed to special hardware instructions (e.g. `POPCNT` for x86). Not all
architectures have hardware instructions for every builtin, so sometimes
these will be emulated in software depending on your target.

2. Hardware intrinsics

For example, `_mm_popcnt_u32(unsigned int)` for x86 on SSE4.2.
This intrinsic looks like a function, and will lower to `POPCNT` in asm.

We'll focus on the second bucket today.

Slate provides architecture support for x86_64, ARM, and RISC-V in its
libc-shim. That means we also need to support intrinsics for those
architectures. Now a quick google search shows that there are ~10000
intrinsics for x86 and arm and much more for RISC-V.

If I were to write out every signature by hand, I probably wouldn't
transcribe all the signatures before dying (of boredom). So we have to
have another approach.

Thankfully, the compiler authors and hardware manufacturers have us covered.

## Read the Manual

Intel provides an xml file that you can parse for every intrinsic,
what its name is, its arguments, its return type, a doc string, what cpu
features it uses, what header file it belongs in, etc.
ARM does something similar, except in JSON, and RISC-V provides a
python script that generates all of its headers, because it has a lot
more intrinsics than either x86 or ARM.

You can use these to generate the header files themselves. In clang, the
way this is done is by parsing the manual files, and then generating
definitions in a DSL called `tablegen`. This is used all through clang,
and it is a somewhat C looking language that is used for generating all
kinds of things, include llvm instructions, Clang's IR (which we'll get
to another time)

How this flows through clang looks like this:

```txt
┌─────────────────────────────┐
│ ISA manual                  │
│ (Arm ARM, RISC-V RVV spec,  │
│ Intel SDM)                  │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ hand-written TableGen       │
│ (arm_neon.td, arm_sve.td,   │
│ RISCVVectorBuiltins.td)     │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ clang-tblgen emitter        │
│ (NeonEmitter / SveEmitter / │
│ RVV intrinsic emitter,      │
│ `-gen-arm-neon` etc.)       │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ generated C header          │
│ (immintrin.h, arm_neon.h,   │
│  arm_sve.h, riscv_vector.h) │
│                             │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ used by CGBuiltin.cpp       │
│ + Sema to map builtin call  │
│ -> llvm.* intrinsic at      │
│ CIR/IR emission time        │
└─────────────────────────────┘
```

Sadly that last point means slate can't just copy paste clang's headers
into `libc-shim` and call it a day. The Clang IR (CIR) that it reads
turns into raw llvm intrinsics.

## The power of Tablegen

Since Slate is pinned to a given Clang version (since Clang IR isn't
built by default for Clang yet), we can use their tablegen parser. This
allows us to get all the information that clang records for each
intrinsic, and then change its form to something slate can recognize.

To that end, there's a support crate for slate called
`slate-intrinsic-gen` that parses each tablegen and creates a struct for
each entry that looks like:

```rust
IntrinsicSignature {
    name: "llvm.x86.sse42.crc32.32.8",
    overloaded: false,
    ret: Some("i32"),
    params: Some(&[
        IntrinsicParam {
            llvm_type: "i32",
            immarg: false,
        },
        IntrinsicParam {
            llvm_type: "i8",
            immarg: false,
        },
    ]),
    overloaded_positions: None,
}
```

This allows us to recover the whole name itself. For example, for this program:

```c
__attribute__((target("sse4.2"))) static unsigned long long crc32_probe(void) {
  unsigned int crc = _mm_crc32_u8(0u, 0x12u);
  crc              = _mm_crc32_u16(crc, 0x3456u);
  crc              = _mm_crc32_u32(crc, 0x789abcdeu);
  return _mm_crc32_u64(crc, 0x123456789abcdef0ull);
}
```

Slate will generate something like this:

```rust
#[target_feature(enable = "sse4.2")]
unsafe fn _mm_crc32_u8(a: u32, b: u8) -> u32 {
    unsafe { __slate_intrinsic_x86_sse42_crc32_32_8_f27bf8581dad0801(a, b) }
}

#[target_feature(enable = "sse4.2")]
unsafe fn _mm_crc32_u16(a: u32, b: u16) -> u32 {
    unsafe { __slate_intrinsic_x86_sse42_crc32_32_16_658f6bf45a185a4a(a, b) }
}

#[target_feature(enable = "sse4.2")]
unsafe fn _mm_crc32_u32(a: u32, b: u32) -> u32 {
    unsafe { __slate_intrinsic_x86_sse42_crc32_32_32_f5e6b09e791bc818(a, b) }
}

#[target_feature(enable = "sse4.2")]
unsafe fn _mm_crc32_u64(a: u64, b: u64) -> u64 {
    unsafe { __slate_intrinsic_x86_sse42_crc32_64_64_a6b1e708219fb1bb(a, b) }
}

#[target_feature(enable = "popcnt,sse3,sse4.1,sse4.2,ssse3")]
unsafe fn crc32_probe() -> u64 {
    let v1: u32 = unsafe { _mm_crc32_u8(0, 18) };
    let v2: u32 = unsafe { _mm_crc32_u16(v1, 13398) };
    let v3: u32 = unsafe { _mm_crc32_u32(v2, 2023406814) };
    let v4: u64 = 1311768467463790320u64;
    unsafe { _mm_crc32_u64(v3 as u64, v4) }
}

unsafe extern "unadjusted" {
    #[link_name = "llvm.x86.sse42.crc32.32.8"]
    fn __slate_intrinsic_x86_sse42_crc32_32_8_f27bf8581dad0801(_0: u32, _1: u8) -> u32;
    #[link_name = "llvm.x86.sse42.crc32.32.16"]
    fn __slate_intrinsic_x86_sse42_crc32_32_16_658f6bf45a185a4a(_0: u32, _1: u16) -> u32;
    #[link_name = "llvm.x86.sse42.crc32.32.32"]
    fn __slate_intrinsic_x86_sse42_crc32_32_32_f5e6b09e791bc818(_0: u32, _1: u32) -> u32;
    #[link_name = "llvm.x86.sse42.crc32.64.64"]
    fn __slate_intrinsic_x86_sse42_crc32_64_64_a6b1e708219fb1bb(_0: u64, _1: u64) -> u64;
}
```

Now note that slate does all of its external linking itself, since not
all intrinsics in clang are supported by rust.

But there's one thing wrong here: the tablegen says crc32's signature
takes a `i32 and i8` and returns an `i32` but the intrinsic itself is
all unsigned (`u32 and u8` returning a `u8`). What gives?

## Some thorns in our side (Overrides)

Note that actually some functions have different signatures, used to
disambiguate what the actual function is:

So we keep a separate table that contains the overridden link name, its
params and return type as well, so we can use this to generate what we
want. For `crc32.32.8`, that means we override its parameters:

```rust
StdarchOverride {
    link_name: "llvm.x86.sse42.crc32.32.8",
    params: &["u32", "u8"],
    ret: Some("u32"),
},
```

Also, there's another thorn in our side where rust's target features
don't map to LLVM's:

for example, `crc32` functionality is gated behind the feature flag
`crc32` in clang. In Rust, this is gated behind the broader `sse4.2`
flag. Likewise `bmi`, bit manipulation instructions for haswell is
different on clang than it is in rust, `bmi1`. So we have to
disambiguate that as well.

## Why bother?

If we pass the previous program to C2Rust, note that it'll lean on rust
to emit the right intrinsics:

```rust
#![feature(stdsimd)]
#[cfg(target_arch = "x86")]
pub use ::core::arch::x86::{_mm_crc32_u8, _mm_crc32_u16, _mm_crc32_u32};
#[cfg(target_arch = "x86_64")]
pub use ::core::arch::x86_64::{
    _mm_crc32_u8, _mm_crc32_u16, _mm_crc32_u32, _mm_crc32_u64,
};

unsafe extern "C" fn crc32_probe() -> ::core::ffi::c_ulonglong {
    let mut crc: ::core::ffi::c_uint = _mm_crc32_u8(
        0 as ::core::ffi::c_uint,
        0x12 as ::core::ffi::c_uchar,
    );
    crc = _mm_crc32_u16(crc, 0x3456 as ::core::ffi::c_ushort);
    crc = _mm_crc32_u32(crc, 0x789abcde as ::core::ffi::c_uint);
    return _mm_crc32_u64(
        crc as ::core::ffi::c_ulonglong,
        0x123456789abcdef0 as ::core::ffi::c_ulonglong,
    );
}
```

Which works, most of the time. Rust supports almost all intrinsics for
x86 that return a value, however, it doesn't support the intrinsics that
are used for their effects:

For example, take this program that flushes the cache line(s) for the
CPU:

```c
#include <immintrin.h>
#include <stdio.h>

__attribute__((target("clflushopt"))) void flush(void *addr) {
    __builtin_ia32_clflushopt(addr);
    _mm_sfence();
}

int main(void) {
    int x = 42;
    flush(&x);
    printf("%d\n", x);
    return 0;
}
```

There is no intrinsic for this in the Rust stdlib, so the `flush`
function gets deleted by C2Rust wholesale:

```rust
#[cfg(target_arch = "x86")]
pub use ::core::arch::x86::_mm_sfence;
#[cfg(target_arch = "x86_64")]
pub use ::core::arch::x86_64::_mm_sfence;
extern "C" {
    fn printf(__format: *const ::core::ffi::c_char, ...) -> ::core::ffi::c_int;
}
unsafe fn main_0() -> ::core::ffi::c_int {
    let mut x: ::core::ffi::c_int = 42 as ::core::ffi::c_int;
    flush(&raw mut x as *mut ::core::ffi::c_void); // flush called
    // without a definition
    printf(b"%d\n\0".as_ptr() as *const ::core::ffi::c_char, x);
    return 0 as ::core::ffi::c_int;
}
pub fn main() {
    unsafe { ::std::process::exit(main_0() as i32) }
}
```

By adding the mapping yourself, you can translate this program and get
the same result as the C would.

```rust
#![feature(clflushopt_target_feature)]
#![feature(abi_unadjusted)]
#![feature(link_llvm_intrinsics)]
#![feature(c_variadic)]
#![allow(
    dead_code,
    unused,
    non_camel_case_types,
    non_snake_case,
    non_upper_case_globals,
    arithmetic_overflow,
    unconditional_panic,
    suspicious_runtime_symbol_definitions,
    unpredictable_function_pointer_comparisons,
    unused_comparisons
)]

unsafe extern "C" {
    fn printf(_0: *const core::ffi::c_char, ...) -> i32;
}

#[target_feature(enable = "clflushopt")]
unsafe fn flush(_v0: *mut core::ffi::c_void) {
    unsafe {
        unsafe { __slate_intrinsic_x86_clflushopt_2bf6694e0a93403a(_v0) };
    }
    unsafe {
        unsafe { __slate_intrinsic_x86_sse_sfence_f8b270d178b3d220() };
    }
    return;
}

fn main() {
    let mut x: i32 = 42;
    let _v2: *mut core::ffi::c_void = std::ptr::addr_of_mut!(x) as *mut core::ffi::c_void;
    unsafe { flush(_v2 as *mut core::ffi::c_void) };
    unsafe { printf(c"%d\n".as_ptr(), x) };
    std::process::exit(0 as i32);
}

unsafe extern "unadjusted" {
    #[link_name = "llvm.x86.clflushopt"]
    fn __slate_intrinsic_x86_clflushopt_2bf6694e0a93403a(_0: *mut core::ffi::c_void);
    #[link_name = "llvm.x86.sse.sfence"]
    fn __slate_intrinsic_x86_sse_sfence_f8b270d178b3d220();
}
```

## In Sum

The whole flow looks like this:

```txt
┌─────────────────────────────┐
│ C source                    │
│ _mm_add_epi32(..)           │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Clang + CIR                 │
│ (headers inlined, resolved  │
│ to LLVM intrinsic call)     │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ cir.call_llvm_intrinsic op  │
│ (llvm.x86.foo, concrete     │
│ operand/result types)       │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐        ┌─────────────────────────────┐
│ intrinsics.rs               │        │  slate-intrinsic-gen        │
│ mangled_link_name /         │        │ (offline, once per LLVM     │
│ find_stdarch_override       │◀───────│ stdarch version — mines     │
│ against intrinsics_table.rs │        │ Intrinsics.h + stdarch      │
│                             │        │ #[link_name] attrs)         │
└──────────────┬──────────────┘        └─────────────────────────────┘
               │
               ▼
┌─────────────────────────────┐
│ extern "unadjusted"         │
│ #[link_name = "llvm.foo"]   │
│ fn decl (shim)              │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ generated Rust fn call site │
│ (compiled + run)            │
└─────────────────────────────┘
```
