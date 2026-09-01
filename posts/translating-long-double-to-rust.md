---
title: "Translating Long Double to Rust"
date: 2026-08-12T12:04:52-04:00
draft: false
---

I've been working on [Slate](https://github.com/takashiidobe/slate),
a C to Rust translator. There are a few particularly thorny parts of
translating C to Rust, but given how much `long double` made me suffer,
I've decided to write it up.

If you've never used `long double`, you may breathe a sigh of relief. If
you use either `f64` (`double`) or `f128`s (`_Float128/__float128`)
then you're absolved of sin and free to go. The heathens who wish to
learn suffering may stay till the rest of the post to learn more.

`long double` has been around since C89. The standard just says that it
must be as precise as `double` (`f64`). Because of this, long double can
be pretty much any bit-size from 64-bits to infinite bits. In practice,
there are a few dominant ones:

1. f64. MSVC does this for x86.
2. f80. GCC + Clang do this for x86. This is padded to 12-bytes or 16-bytes.
3. double-double. Two f64s glued together. For older PowerPC and IBM
   architectures.
4. f128. Arm64, PowerPC, RISC-V.

`f64` and `f128` are not hard to support. On a target where `long
double` == `f64`/`f128`, you would just swap out every long double you
see for the appropriate type in rust, and when you pass it to extern C
code, it'll be bit aligned and properly handled.

`f80` is the real problem, and what the rest of the blog will explain.
Afaik, [C2Rust doesn't support `long double` properly because it
translates to f128](https://github.com/immunant/c2rust/issues/1723).
There have been efforts in the past to add `f80` support, but this'll
probably take a while.

## Representing f80

With long double, we need to be able to do anything you would normally
be able to do with the type in C. That means the arithmetic ops, casting to
and from, passing to functions as value or pointer, and being able to
use it in callbacks.

A first try is this:

```rust
#[repr(C, align(16))]
#[derive(Clone, Copy)]
pub struct LongDouble { bytes: [u8; 10] };
```

With this we fulfill the requirements of its size and alignment. We
could then even emulate the f80 math itself in rust, so when you call
any long double function that has been translated to rust, and call a
non-translated C function, the bits are all perfectly legal.

Sadly, long doubles are passed in floating point registers, whereas
these chars are passed in general purpose registers, so trying to
implement this as is will cause corruption.

We can have the rust type be plain bytes and implement every operation
as asm:

```rust
pub unsafe fn add(self, rhs: Self) -> Self {
    let mut out = LongDouble { bytes: [0; 10] };

    unsafe {
        core::arch::asm!(
            "fld tbyte ptr [{a}]",
            "fld tbyte ptr [{b}]",
            "faddp st(1), st(0)",
            "fstp tbyte ptr [{out}]",

            a   = in(reg) self.bytes.as_ptr(),
            b   = in(reg) rhs.bytes.as_ptr(),
            out = in(reg) out.bytes.as_mut_ptr(),

            out("st(0)") _,
            out("st(1)") _,
            out("st(2)") _,
            out("st(3)") _,
            out("st(4)") _,
            out("st(5)") _,
            out("st(6)") _,
            out("st(7)") _,
        );
    }

    out
}
```

This works, but you would have to implement every primitive long double
op yourself in handwritten assembly. (If you heard a groan, that was
me).

Instead, here's a nice trick: you can shim the calls and let libc do the rest.

So on the rust side:

```rust
#[repr(C, align(16))]
#[derive(Clone, Copy)]
pub struct LongDouble(pub [u8; 10]);

unsafe extern "C" {
    fn __slate_ld_add(a: LongDouble, b: LongDouble) -> LongDouble;
    // whatever other ops you want to provide
}
```

Use the same storage on the C side:

```c
typedef struct {
    _Alignas(16) unsigned char bytes[10];
} slate_f80;
```

And then write two functions, one to convert chars to long double and
one back:

```c
static inline long double unpack(slate_f80 v) {
    long double x = 0.0L;

    memcpy(&x, v.bytes, 10);
    return x;
}

static inline slate_f80 pack(long double x) {
    slate_f80 v = {0};

    memcpy(v.bytes, &x, 10);
    return v;
}
```

```c
slate_f80 __slate_ld_add(slate_f80 a, slate_f80 b) { return pack(unpack(a) + unpack(b)); }
slate_f80 __slate_ld_sub(slate_f80 a, slate_f80 b) { return pack(unpack(a) - unpack(b)); }
slate_f80 __slate_ld_mul(slate_f80 a, slate_f80 b) { return pack(unpack(a) * unpack(b)); }
slate_f80 __slate_ld_div(slate_f80 a, slate_f80 b) { return pack(unpack(a) / unpack(b)); }
slate_f80 __slate_ld_neg(slate_f80 a) { return pack(-unpack(a)); }
```

You could also implement casting, relops in the same way:

```c
int __slate_ld_eq(slate_f80 a, slate_f80 b) { return unpack(a) == unpack(b); }
int32_t __slate_ld_to_i32(slate_f80 a) { return (int32_t)unpack(a); }
slate_f80 __slate_ld_from_i32(int32_t x) { return pack((long double)x); }
```

Likewise, for any arbitrary function:

```c
long double custom(long double, int);
```

You would replace it with a call to:

```c
slate_f80 __slate_custom(slate_f80 a, int b) { return pack(custom(unpack(a), b)); }
```

This makes it so we don't have to know anything about the underlying
long double type at all (no assembly writing for me) and keeps our
shim code fairly light.
