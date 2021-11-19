---
title: "Cross compilation for fun and profit"
date: 2021-11-07T21:40:37-06:00
draft: true
---

# Cross Compilation

Why cross compile? Well, given that we want our programs to be
accessible to as many users as possible, we should want users of many
platforms being able to use our programs.

Why does programming language matter in this case? If you choose a language 
that compiles bytecode, you can only run the code on platforms that can
run the VM for your code. 

## Python

According to <https://pythondev.readthedocs.io/platforms.html>, python
supports six architectures:

- x86_32
- x86_64
- PowerPC64le
- ARM64/AArch64
- Armv7
- s390x

## Java

According to
<https://www.oracle.com/java/technologies/javase/products-doc-jdk8-jre8-certconfig.html>,
java supports the following architectures:

- x86_32
- x86_64,
- Sparc64
- Armv7hf
- ARM64/AArch64 

It's pretty clear that neither Java or Python support a wide range of
architectures. It's not impossible to port these languages, 
but it is a difficult task to port the language and their standard
libraries, so the developers decided to only target popular architectures.

Let's compare the above two languages to something like C, which has a
tiny standard library in comparison and simple language, which makes it
easy to port:

## GCC

GCC supports 78 architectures.

- Alpha
- ARM
- AVR
- Blackfin
- Epiphany (GCC 4.8)
- H8/300
- HC12
- IA-32 (x86)
- IA-64 (Intel Itanium)
- MIPS
- Motorola 68000
- PA-RISC
- PDP-11
- PowerPC
- R8C / M16C / M32C
- SPARC
- SuperH
- System/390 / zSeries
- VAX
- x86-64
- Nvidia GPU
- Nvidia PTX
- AArch64
- RISC-V
- MSP430
- eBPF
- 68HC11
- A29K
- CR16
- C6x
- D30V
- DSP16xx
- ETRAX CRIS
- FR-30
- FR-V
- Intel i960
- IP2000
- M32R
- MCORE
- MIL-STD-1750A
- MMIX
- MN10200
- MN10300
- Motorola 88000
- NS32K
- IBM ROMP
- RL78
- Stormy16
- V850
- Xtensa
- Cortus APS3
- ARC
- AVR32
- C166 and C167
- D10V
- EISC
- eSi-RISC
- Hexagon
- LatticeMico32
- LatticeMico8
- MeP
- MicroBlaze
- Motorola 6809
- MSP430
- NEC SX architecture
- Nios II and Nios
- OpenRISC
- PDP-10
- PIC24/dsPIC
- PIC32
- Propeller
- Saturn (HP48XGCC)
- System/370
- TIGCC (m68k variant)
- TMS9900
- TriCore
- Z8000
- ZPU

## Clang

Clang supports a bit less (55 architectures) according to this header
file from llvm: <https://llvm.org/doxygen/Triple_8h_source.html>.

- arm,
- armeb,
- aarch64,
- aarch64_be,
- aarch64_32,
- arc,
- avr,
- bpfel,
- bpfeb,
- csky,
- hexagon,
- m68k,
- mips,
- mipsel,
- mips64,
- mips64el,
- msp430,
- ppc,
- ppcle,
- ppc64,
- ppc64le,
- r600,
- amdgcn,
- riscv32,
- riscv64,
- sparc,
- sparcv9,
- sparcel,
- systemz,
- tce,
- tcele,
- thumb,
- thumbeb,
- x86,
- x86_64,
- xcore,
- nvptx,
- nvptx64,
- le32,
- le64,
- amdil,
- amdil64,
- hsail,
- hsail64,
- spir,
- spir64,
- kalimba,
- shave,
- lanai,
- wasm32,
- wasm64,
- renderscript32,
- renderscript64,
- ve,

There's no comparison. Languages that target gcc and llvm support a
wider array of architectures. If you're using a less popular architecture, 
and your library writers are using gcc or clang, you're in luck. If they arent't, you're SOL.

## A Note on standard libraries
