---
title: "Assembly Language"
date: 2025-12-02T22:28:56-05:00
draft: false
---

Confession: I don't know much about assembly. Thankfully compilers are
good enough these days that it doesn't matter, but I've always been
curious about writing assembly as is. I ended up writing some m68k
assembly last post when writing an m68k to x86_64 interpreter. So I had
the bright idea to write my own assembly language. For fun.

Now the actual plan was as follows: write an assembly language spec,
write an interpreter, and write an encoder/decoder (so I could test out
how different design decisions affected code density in the binary). My
first order of business was to decide on the size of my opcodes. I
decided to go with 16-bit like the m68k -- I thought it would be spartan
enough to not endlessly iterate and be compact yet give me enough space
to design instructions. My first decision was to reverse one design
decision I think hampered the m68k, splitting registers into address and
data registers.

On the m68k, there are 16 32-bit registers. This is for a CPU that came
out in 1979; compare it to a similar Intel CPU at the time, the 8086.
The 8086 came with 8 16-bit registers. You get 2 times the registers
with 2 times the bit-width. Sadly, with the data register/address
register split, the 8 data registers store the usual data and the 8
address registers are for indirect accessing of memory. I assume this
was chosen because this made registers take 3-bits (2^3 = 8) instead of
4-bits (2^4 = 16), and because the m68k had support for 8 effective
addressing modes on its two operands, which took up 6 bits in total (EA
+ Reg). Given a 4-bit group, you'd be left with another 3 bits for the
register for a binary operator, or to do what you wanted. 

I wanted to see if it was possible to support 16 registers, so I bit the
4-bit bullet per register. Given that an instruction set needs to have
at least 30 must have instructions, you also need to reserve at least
5 bits for every instruction so you know which opcode to use. I
decided to go with a scheme that would allow me to have up to 64
instructions -- a 4-bit major group, with a further 2-bits subdividing
each group with 4 instructions each, so I would have 16 groups with 4
subgroups in each group. This left me with 10-bits. You see the problem.
If each register costs you 4-bits, and you have 2 of them, you're left
with 2 bits per instruction. But wait, there's more. Each instruction
must also carry bits for its size. I wanted 16 64-bit registers, so each
instruction had to support an 8-bit, 16-bit, 32-bit, and 64-bit variant
(I called these byte, short, long, word). This is 4 choices, so this
takes up 2-bits.

So there you have it. Each binary instruction has 4-bits for group,
4-bits for subgroup, 2-bits for size, 4-bits for register 1 (which is
the target) and 4-bits for register 2. This works out for most
instructions, like arithmetic ones, but you cannot do an arithmetic
operation + change the addressing mode. 

To do so, I added three instructions as full 12-bit instructions. `lea`,
(load effective address), a load and store instruction. These took up
4 instructions a pop (since they take up a whole group), but I was able
to cram in a 2-bit effective address for each of these.

The effective addresses are:

1. register direct, as is: `%rX`
2. register indirect, the address of the register, `(%rX)`
3. immediate, `$10`
4. offset indirect `-4(%sp)`

Since you can only place this on either the src or the target, this is a
bit barebones, but it works out fine. 

I decided not to go with a condition flag design (like m68k, arm, x86)
and take a flagless design -- in exchange though, you have to implement
a lot of branching operations. For the branching instructions:

1. Branch if Equal
2. Branch if not equal
3. Branch less than
4. Branch less than equal
5. Branch if Zero
6. Branch if not zero

I could've gone with a sparser set, but I figured it'd be ok to use the
instructions since branching is quite commonplace. For the cmp side, I
decided to go with a sparser set, explicitly requiring a not or a flip
of operands to get `<=`, `>`, and `>=`.

1. Cmp equal
2. Cmp not equal
3. Cmp less than equal
4. Cmp less than

I also wanted compact operations that used immediates a lot, so I
provided immediate verisons of add, sub, mul, mov. If I dropped the
size, I could have 6-bits left over. So I can have immediates from
0..63. However, I really wanted to be able to use `64`. It turns out you
actually can support the range of 0..64 for these ops:

For `add` and `sub` with 0, this does nothing, so you can read this code
and emit a no-op instead. For `mul` and `mov`, it zeroes out the target
register. You can do the same with `xor %rX, %rX`, which zeroes out the
target register. Thus, in the textual assembly format, You can support
65 values (which requires 7-bits) by rewriting the last case to
something supported. You can also do this with div (rewrite `div %rX,
$0` with `trap`), or `mod` as well. 

I decided to add a few extra assembly directives:

- `.byte` to include a byte array,
- `.ascii` to include an ascii string,
- `.asciz` to include an ascii string with a null terminator
- `.include` to include the file copy pasted as in C, to link multiple
  assembly files together.

After hooking up syscall write on linux, you can write assembly pretty
well:

```asm
        movi %r0, $1         # syscall write 
        movi %r1, $1         # stdout
        load.l %r2, msg      # r2 = &msg
        movi %r3, $12        # length
        trap                 # perform write
        ret

msg:
        .asciz "hello world\n"
```

And recursive fibonacci isn't so bad:

```asm
# Calculate fib(10)
        movi %r1, $10        # n = 10
        call fib
        jmp done

fib:
        # Prologue: save caller-saved registers
        push.w %r2
        push.w %r3

        # Base case: if n == 0, return 0
        brz.l %r1, base_case

        # Base case: if n == 1, return 1
        mov.l %r3, %r1
        subi.l %r3, $1
        brz.l %r3, base_case

        # Recursive case: fib(n-1)
        subi  %r1, $1
        push.w %r1            # Save n-1
        call fib
        mov.l %r2, %r0        # r2 = fib(n-1)
        pop.w %r1             # Restore n-1

        # fib(n-2)
        subi.l %r1, $1
        push.w %r1
        call fib
        mov.l %r3, %r0        # r3 = fib(n-2)
        pop.w %r1

        # Return fib(n-1) + fib(n-2)
        mov.l %r0, %r2
        add.l %r0, %r3
        jmp end_fib

base_case:
        mov.l %r0, %r1        # Return n

end_fib:
        # Epilogue: restore registers
        pop.w %r3
        pop.w %r2
        ret

done:
        nop
```

I really enjoyed this project -- it was interesting to design an
assembly language, since it made me value what instructions could be
supported with such little space. I still won't be writing assembly, but
at least I can understand why it's so hard to design a good ISA!
