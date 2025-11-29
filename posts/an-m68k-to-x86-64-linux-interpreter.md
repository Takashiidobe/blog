---
title: "An M68k to x86_64 linux interpreter"
date: 2025-11-28T19:17:00-05:00
draft: false
---

I've always been interested in Virtual Machines, even having a copy of
[Virtual Machines: Versatile
Platforms](https://www.amazon.com/Virtual-Machines-Versatile-Platforms-Architecture/dp/1558609105)
on my bookshelf. I decided it would be fun to implement a program that
could read an m68000 ELF binary and run it on my x86_64 linux computer.
The repo is here: [Behistun](https://github.com/Takashiidobe/behistun/).

First things first, we had to compile some m68k ELF binaries. I fired up
my copy of crosstool and made myself an `m68k-unknown-linux-gnu-gcc`
toolchain. 

To decode a binary, you have to first read the relevant ELF sections of
a binary. To do so, I used the `goblin` library, which took care of
that. The rest was to decode each instruction, and then execute it on a
virtual CPU.

So, I started writing out a file with a new `m68k` assembly
instruction, compiled it, and then tried to decode it with my program.
This would fail, so I would go to work decoding it.

I did this until I implemented the whole `m68000` set, which wasn't too
bad, given that the `m68k` instruction set is pretty compact. After
decoding, I had to write a CPU that would emulate everything, and I was
good to go. This took a bit longer than plain decoding, but after I got
this to work out. Perfect! A fun little weekend project, right?

Unfortunately I wanted more. And this is where the pain really started.
I wanted to compile C code for the `m68000` and run it on my little
interpreter. Couldn't be so bad, right?

Unfortunately not. I wrote `cat` in c and then compiled it and tried to
run it on my interpreter -- decoding error. It turned out that the ELF
binary had smuggled in an `fmove` (floating point register move). Why
does `cat`, a program which does not have any floating point usage, need
to move a floating point register?

No matter what flags you use to compile your code, `glibc` for the
`m68k` target actually is compiled with floating point support. Thus, it's
not possible to use `glibc` as your `libc` for compiling `m68000`.
Bummer. Sadly this took me a day of searching to find out why floating
point registers were being smuggled into my user code. The `-mcpu=X`
flag was useless, even using `-msoft-float` was useless. Anyway, I
decided to go back to crosstool and try to compile a `musl` toolchain.
Musl would never betray me, would it?

Sadly it too requires floating point registers, and thus does not
support the 68000, on `setjmp`, to clear registers. I was losing hope.
But crosstool supports one last libc. `uclibc-ng`. And `uclibc`
delivered. It actually did support non-floating point `m68k` and we were
in business. I compiled for the `m68020` to play it safe (each compiler
takes about 30 minutes to compile on my computer), and was back at my
interpreter, ready to compile some C.

To get `cat` to work though, I needed to do some syscall passthrough. I
needed to map the `m68000`'s pointers from guest to host, and also map
the syscall numbers from m68k linux to x86_64 linux. But once that was
done, I could finally write C, compile to m68000 linux elf, and run it
on my x86_64 linux elf machine. 

Of course, there was a bit more to do -- I had to implement the rest of
the `m68010` and `m68020` instruction set, which I discovered I didn't
complete by using fuzzing to generate random C programs with `csmith`,
so I implemented those instructions, and was off to the races -- all I
had to do was implement syscalls. 

In the end, I decided to translate about 200 or so syscalls, wrote tests
for them, and tested them out against `qemu-m68k-static` for
compatibility. There's plenty more syscalls left to do, but I figured
these would be a good chunk of syscalls, so I was done with that. Maybe
I'll come back and implement the rest of them, who knows. The remaining
ones are really tough, so I skipped most of those.
