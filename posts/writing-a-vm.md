---
title: "Writing a VM"
date: 2024-07-20T11:45:44-04:00
draft: false
---

I promised a while back to learn compilers in earnest -- the programs that
turn your high-level code into the low-level bits that your computer can
execute.

I wrote up a few tree-walk interpreters -- they would tokenize the
programming language provided, parse it, and then execute the AST
itself, executing the code.

Tree-walk interpreters work pretty well for the most part -- they're
easier to write, and have great introspection (each node has all the
info it needs). But it didn't really scratch my itch of going all the
way to the metal.

If I write an assembly file to return the number 10, I would write:

```asm
.globl main
main:
    mov $10, %rax
    ret
```

I can compile that output:

```sh
$ gcc test.s -o a.out
```

And `objdump -d` the generated file:

```sh
$ objdump -d a.out
0000000000401106 <main>:
  401106:	48 c7 c0 0a 00 00 00 	mov    $0xa,%rax
  40110d:	c3                   	ret
```

So our instructions are encoded as `48 c7 c0 0a 00 00 00 c3` as bytes.


`mov $10 %rax` corresponds to `48 c7 c0 0a 00 00 00`, and
`ret` turns into `c3`.

So, our "high-level" assembly that we wrote is turned into those bytes,
and the computer can read those bytes and execute them.

A tree-walk interpreter stops before serializing and deserializing
instructions -- it runs the instructions from in-memory, so there's no
need to dump the state to disk.

To be fair, interpreters have a way to dump the tree that they're
executing to disk, like running this command:

```sh
$ clang -Xclang -ast-dump=json -fsyntax-only -Wno-visibility test.c
# emitted JSON here.
```

So we'd like to do that, by turning our instruction stream from those
high level instructions into bytes, and then being able to read those
bytes back and execute the program from binary.

The way I did was sketching out a VM with a set amount of instructions.
Each instruction would be the first byte (so I had a cap of 256
instructions), and then the following bytes would be the arguments.

Next, I had to handle the arity of each instruction. If you have say
`mov $10, %rax` and `mov %rbx, %rax`, these have to be encoded as two
distinct instructions -- one is an immediate to register move, and the
other is a register to register move, even though they're both called
`mov` in the written assembly.

So, I ended up with some 25 instructions, and each instruction would
slurp up the bytes it wanted from a binary, or serialize to those bytes,
and then voila, as long as you had a VM that could take those bytes and
return them to the assembly instructions, you could write any program
you wanted.

An example program, which would print 10 and then exit would look like
this in assembly:

```asm
putreg 10 R0
printreg R0
ret
```

I could then encode that file as binary:

```sh
$ cargo r -q -- -e print.asm > out.bin
```

And look at its contents:

```sh
$ xxd out.bin
00000000: 010a 0000 0900 00                        .......
```

And run it from the binary format.

```sh
cargo r -q -- -d out.bin
10
```

So the program went all the way from the assembly itself, to bytes, and
then was run properly by the VM.

If you'd like to take a look at the VM code on github I've linked it
here.

[VM Code](https://github.com/takashiidobe/vm)

Next step -- writing a high level language that can emit the bytecode,
so I can go all the way from a high-level language to the bare metal.
