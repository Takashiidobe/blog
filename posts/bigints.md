---
title: "Bigints"
date: 2026-03-02T18:32:16-05:00
draft: false
---

Let's talk about writing Bigints. A Bigint is a data structure that
allows one to do math on integers that are larger than the computer's
register size. On a 64 bit computer, registers are 64 bits, so if you
want to add two numbers that are larger than can fit in 64 bits, you'd
need to put them in two registers or more per number, and then apply
each mathematical operation to all the registers.

Let's start off with a `u128` type. That would look something like this:

```rust
#[derive(Debug, Clone, Copy)]
pub struct Uint128 {
    pub h: u64, 
    pub l: u64, 
}
```

For addition, subtraction, and multiplication thankfully nightly rust has
`overflowing_*`, `widening_*` and `wrapping_*` methods on integers 
that allow us a simple implementation.

```rust
impl std::ops::Add for Uint128 {
    type Output = Self;

    #[inline(never)]
    fn add(self, rhs: Self) -> Self::Output {
        let (l, carry) = self.l.overflowing_add(rhs.l);
        let h = self.h.wrapping_add(rhs.h).wrapping_add(carry as u64);

        Self { l, h }
    }
}
```

```rust
impl std::ops::Sub for Uint128 {
    type Output = Self;

    #[inline(never)]
    fn sub(self, rhs: Self) -> Self::Output {
        let (l, borrow) = self.l.overflowing_sub(rhs.l);
        let h = self.h.wrapping_sub(rhs.h).wrapping_sub(borrow as u64);

        Self { l, h }
    }
}
```

```rust
impl std::ops::Mul for Uint128 {
    fn mul(self, rhs: Self) -> Self::Output {
        let (p0_lo, p0_hi) = self.l.widening_mul(rhs.l);

        let t1_lo = self.l.wrapping_mul(rhs.h);
        let t2_lo = self.h.wrapping_mul(rhs.l);
        let h = p0_hi.wrapping_add(t1_lo).wrapping_add(t2_lo);
        Self { h, l: p0_lo }
    }
}
```

For division we have to handwrite and lean on the `u128` type, but we
get a pretty nice result in the end:

```rust
impl std::ops::Div for Uint128 {
    fn div(self, rhs: Self) -> Self::Output {
        let n = (self.h as u128) << 64 | self.l as u128;
        let d = (rhs.h as u128) << 64 | rhs.l as u128;
        let q = n / d;
        Self {
            l: q as u64,
            h: (q >> 64) as u64,
        }
    }
}
```

The assembly delegates to a compiler builtin called `__udivti3`, so our
code is pretty much loads that up and all the hairy work is done for us.


```asm
<bigints::u128::Uint128 as core::ops::arith::Div>::div:
	push rax
	mov rax, rdx
	or rax, rcx
	je .LBB_2
	call qword ptr [rip + __udivti3@GOTPCREL]
	pop rcx
	ret
.LBB_2:
	lea rdi, [rip + .Lanon.12]
	call qword ptr [rip + core::panicking::panic_const::panic_const_div_by_zero@GOTPCREL]
```

And that's it, right?

Sadly I wrote a bug in the beginning for my platform (x86_64). The
bigints struct has to flip its members since this is a little-endian
platform.

```rust
#[derive(Debug, Clone, Copy)]
pub struct Uint128 {
    pub l: u64, 
    pub h: u64, 
}
```

Otherwise the multiplication incurs two extra `mov`s at the start of the
function to load the members into the right place.

```asm
mov rax, rdx
mov rdx, rcx
mulx r8, rdx, rsi
imul rax, rsi
imul rdi, rcx
add rax, rdi
add rax, r8
```

If you write the struct the other way, i.e:

```rust
#[derive(Debug, Clone, Copy)]
#[cfg(target_endian = "little")]
pub struct Uint128 {
    pub l: u64, // bits 0-63 (lower address)
    pub h: u64, // bits 64-127 (higher address)
}

#[derive(Debug, Clone, Copy)]
#[cfg(target_endian = "big")]
pub struct Uint128 {
    pub h: u64, // bits 64-127 (lower address)
    pub l: u64, // bits 0-63 (higher address)
}
```

Then the two `mov`s disappear from the x86_64 generated codegen.

```asm
mulx r8, rdx, rsi
imul rax, rsi
imul rdi, rcx
add rax, rdi
add rax, r8
```

Now I needed a way to make sure all my operations were closer to native,
so I wrote up a test harness that used `cargo-show-asm` to check the
generated assembly on a variety of platforms (including a big-endian
one, s390x) to make sure that there were no unnecessary moves being
produced. 

I used this and compared my implementations to native to see if they
were being properly optimized and found out that for aarch64, using
`overflowing_sub` and `wrapping_sub` nets this:

```asm
<bigints::u128::Uint128 as core::ops::arith::Sub>::sub:                                                                                                                                                                                                                                                                                                                                
    subs x0, x0, x2                                                                                                                                                                                                                                                                                                                                                                    
    sub x8, x1, x3                                                                                                                                                                                                                                                                                                                                                                     
    cset w9, lo                                                                                                                                                                                                                                                                                                                                                                        
    sub x1, x8, x9                                                                                                                                                                                                                                                                                                                                                                     
    ret                                                                                                                                                                                                                                                                                                                                                                                
```

Whereas the native version looks like so:


```asm
<bigints::u128::Uint128 as core::ops::arith::Sub>::sub:                                                                                                                                                                                                                                                                                                                                
  subs x0, x0, x2
  sbc  x1, x1, x3
  ret
```

While for x86_64, it's properly optimized:

```asm
<bigints::u128::Uint128 as core::ops::arith::Sub>::sub:
	mov rax, rdi
	sub rax, rdx
	sbb rsi, rcx
	mov rdx, rsi
	ret
```

As well, for multiplication, there's an extra instruction due to
scheduling:

```asm
<bigints::u128::Uint128 as core::ops::arith::Mul>::mul:
	mul x9, x2, x1
	mul x8, x2, x0
	umulh x10, x2, x0
	madd x9, x3, x0, x9
	mov x0, x8
	add x1, x9, x10
	ret
```

```asm
<bigints::u128::Uint128 as core::ops::arith::Mul>::mul:
    umulh x10, x0, x2    
    mul x9, x1, x2       
    madd x9, x3, x0, x9  
    mul x0, x0, x2       
    add x1, x9, x10      
    ret
```

I assume this is an LLVM backend issue somewhere, but it's hard to fault
them, I doubt anyone would write this code anyway since the u128 types
exist.

The resulting code is here:
[Bigints](https://github.com/takashiidobe/bigints)
