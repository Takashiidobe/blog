---
title: "Writing Rust for the Atari Mint"
date: 2025-11-28T18:21:40-05:00
draft: false
---

Recently I decided to get into a retrocomputing mood. I watched [Matt
Godbolt's videos on Computerphile talking about how computers
work](https://www.youtube.com/watch?v=8VsiYWW9r48&list=PLzH6n4zXuckpwdGMHgRH5N9xNHzVGCxwf)
and after listening to him talk about learning how to program on these
old computers, I was ready to learn more. I was ready to open my wallet
and buy a retrocomputer and test out programming on these computers. On
ebay an Atari ST costs about $200. I reached into my pocket to grab my
credit card to buy one before coming to the realization that I'm broke.
Luckily, there's a pretty active community programming these retro
computers, complete with emulators. I found a couple emulators
like [aranym](https://aranym.github.io/) [hatari](https://hatari-emu.org/) 
and went on my way. 

You could write code for these emulators in assembly or C, due to there
being a gcc toolchain for them: <https://tho-otto.de/crossmint.php>. I
downloaded gcc, hooked up binutils and libraries, and started to write
some code.

I went to go write some simple coreutils for the emulator, but compiling
my first binary (`rm`), my binary was >100KB. Given that the atari ST was
supposed to run on 1.44MB floppies, eating up a little over 1/15th of
your storage on a 50-line C program is a little absurd.

It turns out that the `libc` that the Atari mint toolchain ships with
links to a library called `mintlib`, which is a pretty complete `libc`,
but its binaries are huge. There's an alternative `libc` which isn't as
complete, called `libcmini`. I linked to that `libc` instead and saw the
familiar file size of 4KB. Nice.

However, the binaries are still pretty large if you think about it. An
assembly version of this would probably fit in a few hundred bytes, so C
in this case does have a pretty large penalty.

I decided to start writing my own minimalistic `libc` and incrementally
build out some parts of it. The first part was the C runtime, `crt0.S`.
Afterwards, writing initializers and finalizers, setting up the stack,
env vars, and jumping to start. All of this was pretty tricky but
doable. Some interesting bits were the system calls:
[mintbind.h](https://github.com/Takashiidobe/mintbox/blob/main/src/libc/include/mint/mintbind.h)
where, given this isn't a Linux OS, a lot of the system calls are pretty
interesting -- there's even a "malloc" so you can delegate memory
management to the kernel.

While writing the libc was fun to see what was under the hood, I wanted
some higher-level code. So I decided I wanted to write Rust. First
things first -- I downloaded the `a.out` toolchain from Thorsten Otto's
website. I needed the ELF one, since that was what rust's toolchain
supported. Next, I had to write up a 
[target.json file](https://github.com/Takashiidobe/mints/blob/main/m68k-atari-mintelf.json), 
describing the properties of the architecture I was targeting.

```json
{
  "arch": "m68k",
  "atomic-cas": false,
  "cpu": "M68040",
  "crt-objects-fallback": "false",
  "crt-static-default": false,
  "crt-static-respected": false,
  "code-model": "large",
  "data-layout": "E-m:e-p:32:16:32-i8:8:8-i16:16:16-i32:16:32-n8:16:32-a:0:16-S16",
  "dynamic-linking": true,
  "eh-frame-header": false,
  "executables": true,
  "has-rpath": true,
  "has-thread-local": true,
  "linker": "m68k-atari-mintelf-gcc",
  "llvm-target": "m68k-unknown-elf",
  "linker-is-gnu": true,
  "linker-flavor": "gcc",
  "pre-link-args": {
    "gcc": [
	  "-nostartfiles",
      "-nostdlib",
      "-m68000",
      "-no-pie"
    ]
  },
  "late-link-args": {
    "gcc": [
      "-Wl,--gc-sections",
      "/home/takashi/current/mintbox/build/objs/crt0.o",
      "-Wl,--start-group",
      "-L/home/takashi/current/mintbox/build",
      "-lcbox",
      "-Wl,--end-group",
      "-lgcc"
    ]
  },
  "max-atomic-width": 32,
  "os": "mint",
  "panic-strategy": "abort",
  "position-independent-executables": false,
  "relocation-model": "static",
  "static-position-independent-executables": false,
  "target-endian": "big",
  "target-mcount": "_mcount",
  "target-pointer-width": 32,
  "vendor": "atari"
}
```

After quite a bit of fumbling around, reading docs online, reading the
forums I was able to compile some code for rust. However, I ran into the
same problem where my binaries were 100KB. I couldn't link to libcmini,
however, since I wanted to link to `alloc` in my no_std Rust code. To do
so, I needed an allocator, which I wanted to delegate to the libc for.
However, this requires `posix_memalign`, which `libcmini` does not
provide. I implemented it in my libc, and was off to the races.

However, Rust turned out to be a pain in a very different way than
writing C. If you try to implement printing with 
[Rust's fmt helpers](https://github.com/Takashiidobe/mints/blob/main/src/lib.rs#L38-L43)
when you try to print a type that can't be "inlined" by the compiler,
it'll pull in compiler builtins, and bundle a 300KB runtime, bloating
your binary by that much. If you for example, try to debug print an
integer, that's 300KB. There might be some workaround by using
`args.as_str()` and failing, but this didn't work in my case. So I
decided to stop here. But it was a fun experiment.
