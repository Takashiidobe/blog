---
title: "Writing Your own Libc"
date: 2023-02-16T16:05:35-05:00
draft: false
---

Note: This code was taken from Linux's nolibc: <https://github.com/torvalds/linux/tree/master/tools/include/nolibc>. Check it out to learn more about implementing libc!

# What are System Calls?

Let's write some libc functions.

Libc is C's standard library, which implements a group of functions that can be used by all C programs. Libc provides wrappers for OS level constructs, like `printf`, `open`, `puts`, and so on.

There's two parts to libc:

1. functions like `max`, or `islower`, which don't require any system calls.
2. functions that do require system calls, like `write`, `read`, or `open`.

Functions in the first category can be implemented without calling into the OS.

For example, `max` would look like this:

```c
int max(int a, int b) {
  return a > b ? a : b;
}
```

or `islower`:

```c
int islower(int c) {
  return (c >= 'a' && c <= 'z') ? 1 : 0;
}
```

However, when writing our own `write` or `read` or `open`, we hit a roadblock:

```c
int open(const char* path, int flags, ...) {
  // how do I open a file???
}
```

Open is a system call that needs to manipulate hardware; we need to ask the OS to do the action for us before being able to read and/or write to the file.

The OS supports an interface to facilitate that, called `system calls`. These system calls allow us to request the OS to do something on our behalf. These calls normally manipuluate hardware in some fashion, or have to do with processes.

So `open` might look like this:

```c
int open(const char* path, int flags, ...) {
  return system_call(SYSCALL_OPEN, path, flags, ...);
}
```

And we defer to the OS, which takes care of everything for us.

That leaves the question: what should our `system_call` function look like? And what is `SYSCALL_OPEN`?

## System Call Numbers

System calls take as their first argument a number, which indicates what system call the OS should execute. The OS then reads the first argument from the `system_call` function, looksup which system call it corresponds to, and the remaining arguments, and executes that system call.

Let's say that we call open, which is the number 2:

```c
#define SYSCALL_OPEN 2
system_call(SYSCALL_OPEN, path, flags, ...);
```

The OS will then take that number and run the desired code.

```c
#define SYSCALL_OPEN 2

int system_call(SYSCALL syscall, ...) {
  switch (syscall) {
    case SYSCALL_OPEN:
      // run code to open up a file in the hardware
      break;
    default:
      break;
  }
}
```

We now need a correct list of system calls. Imagine if we thought `SYSCALL_OPEN` was `3`, but the OS thought `3` means `close`:

The computer could crash, our process could crash, anything could happen.


```c
#define SYSCALL_OPEN 3
system_call(SYSCALL_OPEN, path, flags, ...);
```

```c
#define SYSCALL_OPEN  2
#define SYSCALL_CLOSE 3

int system_call(SYSCALL syscall, ...) {
  switch (syscall) {
    case SYSCALL_OPEN:
      // run code to open up a file in the hardware
      break;
    case SYSCALL_CLOSE:
      // run code to close  a file
      // oops, we called the wrong function
      break;
    default:
      break;
  }
}
```

So we need to get that list of system calls:

You can find the system calls in your linux system with `ausyscall`:

```sh
$ ausyscall --dump

Using x86_64 syscall table:
0       read
1       write
2       open
3       close
...
```

This differs per architecture:

for example, on aarch64 (ARM 64 bit):

```sh
$ ausyscall aarch64 --dump
Using aarch64 syscall table:
0       io_setup
1       io_destroy
2       io_submit
3       io_cancel
```

We could define these ourselves, or rely on the system to export them at `asm/unistd.h`. I'm going to include it instead of rewriting it.

```c
#include <asm/unistd.h>
```

## Writing system calls (with assembly)

Now that we have the system call number we need, let's write that syscall!

We need to know a few things:

1. What the system call function is called, so we can tell the OS we're running a system call
2. Where to put the system call number
3. Where to put any other arguments required (`open` needs a file to open, for example)
4. Where our return values are placed.

What better way to learn than through the manual pages: run `man 2 syscall` in the shell to learn more:

First, there's a table that tells us what a system call is called in the `instruction` column. For x86-64, it is called `syscall`. Next, the table tells us the register to put the system call number. In x86-64, it is `rax`. Finally, the registers to check for return values, which in x86-64 are `rax` and `rdx`, and the register to check for errors (in x86-64, no registers store errors after a system call).

```
Arch/ABI    Instruction           System  Ret  Ret  Error    Notes
                                  call #  val  val2
───────────────────────────────────────────────────────────────────
alpha       callsys               v0      v0   a4   a3       1, 6
arc         trap0                 r8      r0   -    -
arm/OABI    swi NR                -       r0   -    -        2
arm/EABI    swi 0x0               r7      r0   r1   -
arm64       svc #0                w8      x0   x1   -
blackfin    excpt 0x0             P0      R0   -    -
i386        int $0x80             eax     eax  edx  -
ia64        break 0x100000        r15     r8   r9   r10      1, 6
m68k        trap #0               d0      d0   -    -
microblaze  brki r14,8            r12     r3   -    -
mips        syscall               v0      v0   v1   a3       1, 6
nios2       trap                  r2      r2   -    r7
parisc      ble 0x100(%sr2, %r0)  r20     r28  -    -
powerpc     sc                    r0      r3   -    r0       1
powerpc64   sc                    r0      r3   -    cr0.SO   1
riscv       ecall                 a7      a0   a1   -
s390        svc 0                 r1      r2   r3   -        3
s390x       svc 0                 r1      r2   r3   -        3
superh      trapa #31             r3      r0   r1   -        4, 6
sparc/32    t 0x10                g1      o0   o1   psr/csr  1, 6
sparc/64    t 0x6d                g1      o0   o1   psr/csr  1, 6
tile        swint1                R10     R00  -    R01      1
x86-64      syscall               rax     rax  rdx  -        5
x32         syscall               rax     rax  rdx  -        5
xtensa      syscall               a2      a2   -    -
```

Later down the page, there's another table that shows where arguments go.

For x86-64, `rdi` `rsi` `rdx` `r10` `r8` `r9` are the registers to put arguments in order, with `rax` being the system call number.

An interesting thing to note: `mips/o32` here only supports 4 arguments in registers. That doesn't necessarily mean it only supports system calls with 4 or less arguments -- arguments 5 through 8 are placed on the stack and read when the system call instruction is executed.

```
Arch/ABI      arg1  arg2  arg3  arg4  arg5  arg6  arg7  Notes
──────────────────────────────────────────────────────────────
alpha         a0    a1    a2    a3    a4    a5    -
arc           r0    r1    r2    r3    r4    r5    -
arm/OABI      r0    r1    r2    r3    r4    r5    r6
arm/EABI      r0    r1    r2    r3    r4    r5    r6
arm64         x0    x1    x2    x3    x4    x5    -
blackfin      R0    R1    R2    R3    R4    R5    -
i386          ebx   ecx   edx   esi   edi   ebp   -
ia64          out0  out1  out2  out3  out4  out5  -
m68k          d1    d2    d3    d4    d5    a0    -
microblaze    r5    r6    r7    r8    r9    r10   -
mips/o32      a0    a1    a2    a3    -     -     -     1
mips/n32,64   a0    a1    a2    a3    a4    a5    -
nios2         r4    r5    r6    r7    r8    r9    -
parisc        r26   r25   r24   r23   r22   r21   -
powerpc       r3    r4    r5    r6    r7    r8    r9
powerpc64     r3    r4    r5    r6    r7    r8    -
riscv         a0    a1    a2    a3    a4    a5    -
s390          r2    r3    r4    r5    r6    r7    -
s390x         r2    r3    r4    r5    r6    r7    -
superh        r4    r5    r6    r7    r0    r1    r2
sparc/32      o0    o1    o2    o3    o4    o5    -
sparc/64      o0    o1    o2    o3    o4    o5    -
tile          R00   R01   R02   R03   R04   R05   -
x86-64        rdi   rsi   rdx   r10   r8    r9    -
x32           rdi   rsi   rdx   r10   r8    r9    -
xtensa        a6    a3    a4    a5    a8    a9    -
```

With all that information out of the way, we want to write a function that does the following:

1. Write out the system call instruction in assembly (`syscall` for x86).
2. Set the `rax` register to the system call we want to call.
3. Read the register has the return value and return it.

On x86, the registers `rcx`, `r11`, `cc`, and `memory` are clobbered by the syscall, so our assembly call must include them in the last line of the syscall instruction. The last line notes the clobbered registers that are overwritten by the OS, as well as other directives.

For an explanation why `rcx` and `r11` are clobbered.

- `rcx`

> `rcx` is clobbered to store the address of the next instruction to return to.

- `r11`

> `r11` is clobbered to store the value of the rflags register.

And for `cc` and `memory`, from: <https://gcc.gnu.org/onlinedocs/gcc/Extended-Asm.html#Extended-Asm>

- `cc`

> The `cc` clobber indicates that the assembler code modifies the flags register. On some machines, GCC represents the condition codes as a specific hardware register; "cc" serves to name this register. On other machines, condition code handling is different, and specifying "cc" has no effect. But it is valid no matter what the target.

- `memory`

> The `memory` clobber tells the compiler that the assembly code performs memory reads or writes to items other than those listed in the input and output operands (for example, accessing the memory pointed to by one of the input parameters). To ensure memory contains correct values, GCC may need to flush specific register values to memory before executing the asm. Further, the compiler does not assume that any values read from memory before an asm remain unchanged after that asm; it reloads them as needed. Using the "memory" clobber effectively forms a read/write memory barrier for the compiler.

> Note that this clobber does not prevent the processor from doing speculative reads past the asm statement. To prevent that, you need processor-specific fence instructions.


So on x86, a system call will look like:

```c
#define syscall0(num)                     \
({                                        \
	long _ret;                              \
	register long _num  asm("rax") = (num); \
	                                        \
	asm volatile (                          \
		"syscall\n"                           \
		: "=a"(_ret)                          \
		: "0"(_num)                           \
		: "rcx", "r11", "memory", "cc"        \
	);                                      \
	_ret;                                   \
})
```

For the Arm64 (aarch64) version:

```c
#define syscall0(num)                    \
({                                       \
	register long _num  asm("x8") = (num); \
	register long _arg1 asm("x0");         \
	                                       \
	asm volatile (                         \
		"svc #0\n"                           \
		: "=r"(_arg1)                        \
		: "r"(_num)                          \
		: "memory", "cc"                     \
	);                                     \
	_arg1;                                 \
})
```

## Writing a C Function that makes a system call

Let's write our first libc function, `getpid`.

`getpid` returns the `pid` of the current process.

It has a signature of `pid_t getpid(void);`, where `pid_t` is `int`.

All we have to do is to make the right system call to the OS and return it.

```c
typedef int pid_t;

pid_t getpid(void) {
	return syscall0(__NR_getpid);
}
```

This should return your pid, and we're done creating a libc function that calls into the kernel.

## Putting it all together

To put it all together, we need to write the `_start` function of our program, since we are going to link to our own libc.

For x86, that means adding this code to the top of your file:

```c
asm(".section .text\n"
    ".weak _start\n"
    ".global _start\n"
    "_start:\n"
    "pop %rdi\n"                // argc   (first arg, %rdi)
    "mov %rsp, %rsi\n"          // argv[] (second arg, %rsi)
    "lea 8(%rsi,%rdi,8),%rdx\n" // then a NULL then envp (third arg, %rdx)
    "xor %ebp, %ebp\n"          // zero the stack frame
    "and $-16, %rsp\n"          // x86 ABI : esp must be 16-byte aligned before call
    "call main\n"               // main() returns the status code, we'll exit with it.
    "mov %eax, %edi\n"          // retrieve exit code (32 bit)
    "mov $60, %eax\n"           // NR_exit == 60
    "syscall\n"                 // really exit
    "hlt\n"                     // ensure it does not return
    "");
```

This sets up everything main needs to run.

For ARM64 (aarch64):

```c
asm(".section .text\n"
    ".weak _start\n"
    ".global _start\n"
    "_start:\n"
    "ldr x0, [sp]\n"              // argc (x0) was in the stack
    "add x1, sp, 8\n"             // argv (x1) = sp
    "lsl x2, x0, 3\n"             // envp (x2) = 8*argc ...
    "add x2, x2, 8\n"             //           + 8 (skip null)
    "add x2, x2, x1\n"            //           + argv
    "and sp, x1, -16\n"           // sp must be 16-byte aligned in the callee
    "bl main\n"                   // main() returns the status code, we'll exit with it.
    "mov x8, 93\n"                // NR_exit == 93
    "svc #0\n"
    "");
```

And aggregating that together:

For x86:

```c
#include <asm/unistd.h>

#define syscall0(num)                     \
({                                        \
	long _ret;                              \
	register long _num  asm("rax") = (num); \
	                                        \
	asm volatile (                          \
		"syscall\n"                           \
		: "=a"(_ret)                          \
		: "0"(_num)                           \
		: "rcx", "r11", "memory", "cc"        \
	);                                      \
	_ret;                                   \
})

asm(".section .text\n"
    ".weak _start\n"
    ".global _start\n"
    "_start:\n"
    "pop %rdi\n"                // argc   (first arg, %rdi)
    "mov %rsp, %rsi\n"          // argv[] (second arg, %rsi)
    "lea 8(%rsi,%rdi,8),%rdx\n" // then a NULL then envp (third arg, %rdx)
    "xor %ebp, %ebp\n"          // zero the stack frame
    "and $-16, %rsp\n"          // x86 ABI : esp must be 16-byte aligned before call
    "call main\n"               // main() returns the status code, we'll exit with it.
    "mov %eax, %edi\n"          // retrieve exit code (32 bit)
    "mov $60, %eax\n"           // NR_exit == 60
    "syscall\n"                 // really exit
    "hlt\n"                     // ensure it does not return
    "");

typedef int pid_t;

pid_t getpid(void) {
	return syscall0(__NR_getpid);
}

int main() {
  return getpid();
}
```

For ARM64 (aarch64):

```c
#define syscall0(num)                    \
({                                       \
	register long _num  asm("x8") = (num); \
	register long _arg1 asm("x0");         \
	                                       \
	asm volatile (                         \
		"svc #0\n"                           \
		: "=r"(_arg1)                        \
		: "r"(_num)                          \
		: "memory", "cc"                     \
	);                                     \
	_arg1;                                 \
})

asm(".section .text\n"
    ".weak _start\n"
    ".global _start\n"
    "_start:\n"
    "ldr x0, [sp]\n"              // argc (x0) was in the stack
    "add x1, sp, 8\n"             // argv (x1) = sp
    "lsl x2, x0, 3\n"             // envp (x2) = 8*argc ...
    "add x2, x2, 8\n"             //           + 8 (skip null)
    "add x2, x2, x1\n"            //           + argv
    "and sp, x1, -16\n"           // sp must be 16-byte aligned in the callee
    "bl main\n"                   // main() returns the status code, we'll exit with it.
    "mov x8, 93\n"                // NR_exit == 93
    "svc #0\n"
    "");

typedef int pid_t;

pid_t getpid(void) {
	return syscall0(__NR_getpid);
}

int main() {
  return getpid();
}
```

Now to compile this program, we can't link to libc, so, assuming the c file is called `main.c`

```sh
$ gcc -static -lgcc -nostdlib -g main.c -o main
```

to compile it, and run it:

```sh
$ ./main
```

Grab the exit status of the binary:

```sh
$? # some random number
```

And we're done with implementing `getpid`!

## Reading and writing to files

`getpid` is a fine starting function, but we want to be able to read and write to files.

Let's start by defining the system calls that take 1 argument to 3 arguments:

In x86-64:

```c
#define syscall1(num, arg1)                      \
({                                               \
	long _ret;                                     \
	register long _num  asm("rax") = (num);        \
	register long _arg1 asm("rdi") = (long)(arg1); \
	                                               \
	asm volatile (                                 \
		"syscall\n"                                  \
		: "=a"(_ret)                                 \
		: "r"(_arg1),                                \
		  "0"(_num)                                  \
		: "rcx", "r11", "memory", "cc"               \
	);                                             \
	_ret;                                          \
})

#define syscall2(num, arg1, arg2)                \
({                                               \
	long _ret;                                     \
	register long _num  asm("rax") = (num);        \
	register long _arg1 asm("rdi") = (long)(arg1); \
	register long _arg2 asm("rsi") = (long)(arg2); \
	                                               \
	asm volatile (                                 \
		"syscall\n"                                  \
		: "=a"(_ret)                                 \
		: "r"(_arg1), "r"(_arg2),                    \
		  "0"(_num)                                  \
		: "rcx", "r11", "memory", "cc"               \
	);                                             \
	_ret;                                          \
})

#define syscall3(num, arg1, arg2, arg3)          \
({                                               \
	long _ret;                                     \
	register long _num  asm("rax") = (num);        \
	register long _arg1 asm("rdi") = (long)(arg1); \
	register long _arg2 asm("rsi") = (long)(arg2); \
	register long _arg3 asm("rdx") = (long)(arg3); \
	                                               \
	asm volatile (                                 \
		"syscall\n"                                  \
		: "=a"(_ret)                                 \
		: "r"(_arg1), "r"(_arg2), "r"(_arg3),        \
		  "0"(_num)                                  \
		: "rcx", "r11", "memory", "cc"               \
	);                                             \
	_ret;                                          \
})
```

In ARM64 (aarch64):

```c
#define syscall1(num, arg1)                       \
({                                                \
	register long _num  asm("x8") = (num);          \
	register long _arg1 asm("x0") = (long)(arg1);   \
	                                                \
	asm volatile (                                  \
		"svc #0\n"                                    \
		: "=r"(_arg1)                                 \
		: "r"(_arg1),                                 \
		  "r"(_num)                                   \
		: "memory", "cc"                              \
	);                                              \
	_arg1;                                          \
})

#define syscall2(num, arg1, arg2)                 \
({                                                \
	register long _num  asm("x8") = (num);          \
	register long _arg1 asm("x0") = (long)(arg1);   \
	register long _arg2 asm("x1") = (long)(arg2);   \
	                                                \
	asm volatile (                                  \
		"svc #0\n"                                    \
		: "=r"(_arg1)                                 \
		: "r"(_arg1), "r"(_arg2),                     \
		  "r"(_num)                                   \
		: "memory", "cc"                              \
	);                                              \
	_arg1;                                          \
})

#define syscall3(num, arg1, arg2, arg3)           \
({                                                \
	register long _num  asm("x8") = (num);          \
	register long _arg1 asm("x0") = (long)(arg1);   \
	register long _arg2 asm("x1") = (long)(arg2);   \
	register long _arg3 asm("x2") = (long)(arg3);   \
	                                                \
	asm volatile (                                  \
		"svc #0\n"                                    \
		: "=r"(_arg1)                                 \
		: "r"(_arg1), "r"(_arg2), "r"(_arg3),         \
		  "r"(_num)                                   \
		: "memory", "cc"                              \
	);                                              \
	_arg1;                                          \
})
```

Next, some definitions that the libc functions will use:

```c
typedef int pid_t;
typedef int mode_t;
typedef int ssize_t;
typedef unsigned long long size_t;

#define STDIN_FILENO  0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2
```

And flags for calls to `open`:

For x86-64:

```c
#define O_RDONLY            0
#define O_WRONLY            1
#define O_RDWR              2
#define O_CREAT          0x40
#define O_EXCL           0x80
#define O_NOCTTY        0x100
#define O_TRUNC         0x200
#define O_APPEND        0x400
#define O_NONBLOCK      0x800
#define O_DIRECTORY   0x10000
```

For Arm64 (aarch64):

```c
#define O_RDONLY            0
#define O_WRONLY            1
#define O_RDWR              2
#define O_CREAT          0x40
#define O_EXCL           0x80
#define O_NOCTTY        0x100
#define O_TRUNC         0x200
#define O_APPEND        0x400
#define O_NONBLOCK      0x800
#define O_DIRECTORY    0x4000
```

Finally, let's define the functions we'll use:

```c
ssize_t close(int fd) {
  return syscall1(__NR_close, fd);
}

int fsync(int fd) {
	return syscall1(__NR_fsync, fd);
}

ssize_t read(int fd, void *buf, size_t count)
{
	return syscall3(__NR_read, fd, buf, count);
}

int open(const char *path, int flags, mode_t mode) {
	return syscall3(__NR_open, path, flags, mode);
}

ssize_t write(int fd, const void *buf, size_t count) {
	return syscall3(__NR_write, fd, buf, count);
}
```

And a helper function, `strlen`:

```c
size_t strlen(const char *str) {
	size_t len;

	for (len = 0; str[len]; len++)
		asm("");
	return len;
}
```

Finally, we can start writing a main function that uses this code:

```c
int main() {
  const char* text = "hello world\n"; // text to write
  write(STDOUT_FILENO, text, strlen(text)); // write text to stdout
  fsync(STDOUT_FILENO); // flush stdout

  const char* file_text = "Hello from file"; // text to write to file
  int fd = open("hello.txt", O_CREAT | O_TRUNC | O_RDWR, 0666); // open, truncate, create file hello.txt
  write(fd, file_text, strlen(file_text)); // write the file text to file
  fsync(fd); // flush hello.txt
  close(fd); // close hello.txt

  fd = open("hello.txt", O_RDONLY, 0666); // open the file hello.txt for reading

  char read_from_file[strlen(file_text) + 1]; // the buffer to read into
  read(fd, (void *)read_from_file, strlen(file_text)); // read from hello.txt to the buffer
  read_from_file[strlen(file_text)] = '\n'; // add a new line to the buffer
  write(STDOUT_FILENO, read_from_file, strlen(read_from_file)); // write the buffer to stdout
  fsync(STDOUT_FILENO); // flush stdout
  close(fd); // close hello.txt
}
```

After compiling it as above, you should have the following text:

```sh
hello world
Hello from file
```

With `hello.txt` containing `Hello from file`.

Writing some simple libc code isn't that hard!
