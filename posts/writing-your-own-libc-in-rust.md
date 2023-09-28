---
title: "Writing Your own Libc in Rust"
date: 2023-05-22T08:58:02-04:00
draft: false
---

A few posts ago, we wrote our own [libc](./writing-your-own-libc.md) in C. There was some inline assembly required to call functions. Lots of languages can call assembly, but since I mainly use rust, I decided to rewrite most of it in rust, since there are some nice advantages.

First: `cfg` definitions are a lot easier to remember. I can never remember if the `#ifdef` for linux is `__LINUX__` or `linux` or `__linux__`, or the `#ifdef`s for other platforms. Apple's is also odd (`__APPLE__`), and there are other `#ifdef`s for targets: `TARGET_OS_IPHONE` `TARGET_IPHONE_SIMULATOR` `TARGET_OS_MAC`, and windows with `_WIN_32` and `_WIN_64`. With android, there's `__ANDROID__` and `__ANDROID_API__` as well. Getting tired? Well, there's also all the architecture related ones, which there are hundreds of, and they're slightly different per compiler, so you have to know which compiler you're using to even define macros.

There are 3 main wrappers around cfgs which are easy to wrap your head around. `not`, which is anything that doesn't fit inside the definition, like `#[cfg(not(target_arch = "x86_64")))]` means anything that isn't `x86_64`. There's `any`, which means for anything that matches an item in the list, like `#[cfg(any(target_arch = "x86_64", target_arch = "i686"))]` for `x86_64` or `i686`. There's `all`, which means that all items must match, like `#[cfg(all(target_arch = "aarch64", target_os = "linux"))]` means to only run on aarch64 linux.

Second: the inline `asm` syntax is much better. You have three choices: `global_asm!`, which lets you write code anywhere, like if you'd like to embed a string into your binary's text section, `asm!`, which goes in the code section, and `llvm_asm!`, which is for llvm specific asm. You don't have to specify clobbers on x86_64, so the relevant `x86_64` syscall code from C:

```c
asm volatile (                                                    \
    "syscall\n"                                                   \
    : "0"(_num)                                                   \
    : "rcx", "r11", "memory", "cc"                                \
);
```

In rust would look like this:

```rust
asm!(
    "syscall",
    in("rax") $nr
);
```

Anyway, let's get started.

## Implementation

Create a new rust binary, and call it whatever you like. I called mine `syscalls`.

```rust
cargo new syscalls
cd syscalls
```

Open up `src/main.rs` and start off with importing the standard assembly library.

```rust
use std::arch::asm;
```

Next, since we'll be supporting `linux`, with `x86_64` [^1] and `aarch64` [^2], we can force every other architecture/OS mix to have a compiler error, so no one will miscompile and have a runtime error.

[^1]: Also known as `amd64`. [Go](https://github.com/golang/go/blob/1176052bb40378272cfbe83d873b65fcc2ed8502/src/go/build/syslist.go#L58) calls it this due to amd coming up with it, whereas intel popularized it, calling it `x86_64`.
[^2]: Also known as `ARM64`. Apple uses `ARM64` whereas others use `aarch64`.

```rust
#[cfg(not(all(
    target_os = "linux",
    any(target_arch = "x86_64", target_arch = "aarch64")
)))]
compile_error!("Only works on linux on aarch64 or x86_64");
```

This is really helpful -- no more running a library and wondering what went wrong at runtime.

So, lets start off with the skeleton of the first syscall function, `syscall0`. We'll generate a function with the name of the syscall, and the syscall's number.
We'll make a compiler error to start off with since we haven't implemented anything yet.

```rust
macro_rules! syscall0 {
    ($name:ident, $nr:expr) => {
        extern "C" fn $name() {
            unsafe {
                compile_error!("not implemented");
            }
        }
    };
}
```

### ARM64

So we'll start implementing syscalls in `ARM64`  first.


Let's look at an example of Hello World in ARM64 to familiarize ourselves with syscalls in ARM64:

Taken from <https://peterdn.com/post/2020/08/22/hello-world-in-arm64-assembly/>

```asm
.data

/* Data segment: define our message string and calculate its length. */
msg:
    .ascii        "Hello, ARM64!\n"
len = . - msg

.text

/* Our application's entry point. */
.globl _start
_start:
    /* syscall write(int fd, const void *buf, size_t count) */
    mov     x0, #1      /* fd := STDOUT_FILENO */
    ldr     x1, =msg    /* buf := msg */
    ldr     x2, =len    /* count := len */
    mov     w8, #64     /* write is syscall #64 */
    svc     #0          /* invoke syscall */

    /* syscall exit(int status) */
    mov     x0, #0      /* status := 0 */
    mov     w8, #93     /* exit is syscall #93 */
    svc     #0          /* invoke syscall */
```

To write, we first set `x0` to the number 1 (`#1`), to set our `fd` to stdout.
Then, we move the message to `x1`, which is write's second argument,
Then we move the len to `x2`, which is write's third argument,
Then we move the number 64 to `w8`, which is the syscall number,
And then we invoke the syscall with `svc` and the number 0.

We do something similar for exit, just without moving any arguments to `x1` or `x2`.

Let's do that for our first syscall:

```rust
#[cfg(target_arch = "aarch64")]
asm!(
    "mov x0, #0",
    "svc #0",
    in("w8") $nr
);
```

with `in("w8") $nr`, we can pass in our system call number, represented by `$nr`, and rust will put it into `w8` for us. This is equivalent to `mov w8 =$nr`, but we don't have to remember that syntax, as the rust compiler will generate it for us.

As well, we'll set the compiler errors for all architectures that aren't `aarch64` for now.

We repeat the following for the next 6 system calls, with `x0-x5` being used as registers to pass in arguments.

```rust
macro_rules! syscall1 {
    ($name:ident, $nr:expr) => {
        extern "C" fn $name(arg1: impl Into<usize>) {
            unsafe {
                #[cfg(target_arch = "aarch64")]
                asm!(
                    "mov x0, #0",
                    "svc #0",
                    in("w8") $nr,
                    in("x0") arg1.into(),
                );
                #[cfg(not(any(target_arch = "aarch64")))]
                compile_error!("not implemented");
            }
        }
    }
}
macro_rules! syscall2 {
    ($name:ident, $nr:expr) => {
        extern "C" fn $name(arg1: impl Into<usize>, arg2: impl Into<usize>) {
            unsafe {
                #[cfg(target_arch = "aarch64")]
                asm!(
                    "mov x0, #0",
                    "svc #0",
                    in("w8") $nr,
                    in("x0") arg1.into(),
                    in("x1") arg2.into(),
                );
                #[cfg(not(any(target_arch = "aarch64")))]
                compile_error!("not implemented");
            }
        }
    }
}

macro_rules! syscall3 {
    ($name:ident, $nr:expr) => {
        extern "C" fn $name(arg1: impl Into<usize>, arg2: impl Into<usize>, arg3: impl Into<usize>) {
            unsafe {
                #[cfg(target_arch = "aarch64")]
                asm!(
                    "mov x0, #0",
                    "svc #0",
                    in("w8") $nr,
                    in("x0") arg1.into(),
                    in("x1") arg2.into(),
                    in("x2") arg3.into(),
                );
                #[cfg(not(any(target_arch = "aarch64")))]
                compile_error!("not implemented");
            }
        }
    }
}

macro_rules! syscall4 {
    ($name:ident, $nr:expr) => {
        extern "C" fn $name(arg1: impl Into<usize>, arg2: impl Into<usize>, arg3: impl Into<usize>, arg4: impl Into<usize>) {
            unsafe {
                #[cfg(target_arch = "aarch64")]
                asm!(
                    "mov x0, #0",
                    "svc #0",
                    in("w8") $nr,
                    in("x0") arg1.into(),
                    in("x1") arg2.into(),
                    in("x2") arg3.into(),
                    in("x3") arg4.into(),
                );
                #[cfg(not(any(target_arch = "aarch64")))]
                compile_error!("not implemented");
            }
        }
    }
}

macro_rules! syscall5 {
    ($name:ident, $nr:expr) => {
        extern "C" fn $name(arg1: impl Into<usize>, arg2: impl Into<usize>, arg3: impl Into<usize>, arg4: impl Into<usize>, arg5: impl Into<usize>) {
            unsafe {
                #[cfg(target_arch = "aarch64")]
                asm!(
                    "mov x0, #0",
                    "svc #0",
                    in("w8") $nr,
                    in("x0") arg1.into(),
                    in("x1") arg2.into(),
                    in("x2") arg3.into(),
                    in("x3") arg4.into(),
                    in("x4") arg5.into(),
                );
                #[cfg(not(any(target_arch = "aarch64")))]
                compile_error!("not implemented");
            }
        }
    }
}

macro_rules! syscall6 {
    ($name:ident, $nr:expr) => {
        extern "C" fn $name(arg1: impl Into<usize>, arg2: impl Into<usize>, arg3: impl Into<usize>, arg4: impl Into<usize>, arg5: impl Into<usize>, arg6: impl Into<usize>) {
            unsafe {
                #[cfg(target_arch = "aarch64")]
                asm!(
                    "mov x0, #0",
                    "svc #0",
                    in("w8") $nr,
                    in("x0") arg1.into(),
                    in("x1") arg2.into(),
                    in("x2") arg3.into(),
                    in("x3") arg4.into(),
                    in("x4") arg5.into(),
                    in("x5") arg6.into(),
                );
                #[cfg(not(any(target_arch = "aarch64")))]
                compile_error!("not implemented");
            }
        }
    }
}
```

Note that the functions take `impl Into<usize>`, and then the args are converted in the body of the function. That means that the caller doesn't have to `as usize` or `try_into().unwrap()` if they don't pass in a `usize`, which is nice, as long as the argument is convertable to a `usize`.

Finally, we're ready to implement some system calls in ARM64!

`exit` takes 0 arguments and has a syscall number of 93, so we use `syscall0!` thusly:

```rust
#[cfg(target_arch = "aarch64")]
syscall0!(exit, 93);
```

And write takes 3 arguments, the `fd`, a string, and a length, and it has a syscall number of 64, so we pass it in:

```rust
#[cfg(target_arch = "aarch64")]
syscall3!(write, 64);
```

And finally, we can write hello world:

```rust
fn main() {
    #[cfg(target_arch = "aarch64")]
    let string = "Hello ARM64\n";

    let ptr = string.as_ptr() as usize;
    let len = string.len();
    write(1usize, ptr, len);
    exit();
}
```

`cargo run` your file to see `Hello ARM64` in all its glory flash onto the screen.

Now we're not done yet -- let's do the same for x86_64!

### x86_64

So for `x86`, `rax` takes in the system call number, and then the registers are the following: `rdi`, `rsi`, `rdx`, `r10`, `r9`, `r8`.

So now we add in those to our syscall macros:

```rust
macro_rules! syscall0 {
    ($name:ident, $nr:expr) => {
        extern "C" fn $name() {
            unsafe {
                #[cfg(target_arch = "aarch64")]
                asm!(
                    "mov x0, #0",
                    "svc #0",
                    in("w8") $nr
                );
                #[cfg(target_arch = "x86_64")]
                asm!(
                    "syscall",
                    in("rax") $nr
                );
                #[cfg(not(any(target_arch = "aarch64", target_arch = "x86_64")))]
                compile_error!("not implemented");
            }
        }
    };
}

macro_rules! syscall1 {
    ($name:ident, $nr:expr) => {
        extern "C" fn $name(arg1: impl Into<usize>) {
            unsafe {
                #[cfg(target_arch = "aarch64")]
                asm!(
                    "mov x0, #0",
                    "svc #0",
                    in("w8") $nr,
                    in("x0") arg1.into(),
                );
                #[cfg(target_arch = "x86_64")]
                asm!(
                    "syscall",
                    in("rax") $nr,
                    in("rdi") arg1.into(),
                );
                #[cfg(not(any(target_arch = "aarch64", target_arch = "x86_64")))]
                compile_error!("not implemented");
            }
        }
    }
}

macro_rules! syscall2 {
    ($name:ident, $nr:expr) => {
        extern "C" fn $name(arg1: impl Into<usize>, arg2: impl Into<usize>) {
            unsafe {
                #[cfg(target_arch = "aarch64")]
                asm!(
                    "mov x0, #0",
                    "svc #0",
                    in("w8") $nr,
                    in("x0") arg1.into(),
                    in("x1") arg2.into(),
                );
                #[cfg(target_arch = "x86_64")]
                asm!(
                    "syscall",
                    in("rax") $nr,
                    in("rdi") arg1.into(),
                    in("rsi") arg2.into(),
                );
                #[cfg(not(any(target_arch = "aarch64", target_arch = "x86_64")))]
                compile_error!("not implemented");
            }
        }
    }
}

macro_rules! syscall3 {
    ($name:ident, $nr:expr) => {
        extern "C" fn $name(arg1: impl Into<usize>, arg2: impl Into<usize>, arg3: impl Into<usize>) {
            unsafe {
                #[cfg(target_arch = "aarch64")]
                asm!(
                    "mov x0, #0",
                    "svc #0",
                    in("w8") $nr,
                    in("x0") arg1.into(),
                    in("x1") arg2.into(),
                    in("x2") arg3.into(),
                );
                #[cfg(target_arch = "x86_64")]
                asm!(
                    "syscall",
                    in("rax") $nr,
                    in("rdi") arg1.into(),
                    in("rsi") arg2.into(),
                    in("rdx") arg3.into(),
                );
                #[cfg(not(any(target_arch = "aarch64", target_arch = "x86_64")))]
                compile_error!("not implemented");
            }
        }
    }
}

macro_rules! syscall4 {
    ($name:ident, $nr:expr) => {
        extern "C" fn $name(arg1: impl Into<usize>, arg2: impl Into<usize>, arg3: impl Into<usize>, arg4: impl Into<usize>) {
            unsafe {
                #[cfg(target_arch = "aarch64")]
                asm!(
                    "mov x0, #0",
                    "svc #0",
                    in("w8") $nr,
                    in("x0") arg1.into(),
                    in("x1") arg2.into(),
                    in("x2") arg3.into(),
                    in("x3") arg4.into(),
                );
                #[cfg(target_arch = "x86_64")]
                asm!(
                    "syscall",
                    in("rax") $nr,
                    in("rdi") arg1.into(),
                    in("rsi") arg2.into(),
                    in("rdx") arg3.into(),
                    in("r10") arg4.into(),
                );
                #[cfg(not(any(target_arch = "aarch64", target_arch = "x86_64")))]
                compile_error!("not implemented");
            }
        }
    }
}

macro_rules! syscall5 {
    ($name:ident, $nr:expr) => {
        extern "C" fn $name(arg1: impl Into<usize>, arg2: impl Into<usize>, arg3: impl Into<usize>, arg4: impl Into<usize>, arg5: impl Into<usize>) {
            unsafe {
                #[cfg(target_arch = "aarch64")]
                asm!(
                    "mov x0, #0",
                    "svc #0",
                    in("w8") $nr,
                    in("x0") arg1.into(),
                    in("x1") arg2.into(),
                    in("x2") arg3.into(),
                    in("x3") arg4.into(),
                    in("x4") arg5.into(),
                );
                #[cfg(target_arch = "x86_64")]
                asm!(
                    "syscall",
                    in("rax") $nr,
                    in("rdi") arg1.into(),
                    in("rsi") arg2.into(),
                    in("rdx") arg3.into(),
                    in("r10") arg4.into(),
                    in("r9") arg5.into(),
                );
                #[cfg(not(any(target_arch = "aarch64", target_arch = "x86_64")))]
                compile_error!("not implemented");
            }
        }
    }
}

macro_rules! syscall6 {
    ($name:ident, $nr:expr) => {
        extern "C" fn $name(arg1: impl Into<usize>, arg2: impl Into<usize>, arg3: impl Into<usize>, arg4: impl Into<usize>, arg5: impl Into<usize>, arg6: impl Into<usize>) {
            unsafe {
                #[cfg(target_arch = "aarch64")]
                asm!(
                    "mov x0, #0",
                    "svc #0",
                    in("w8") $nr,
                    in("x0") arg1.into(),
                    in("x1") arg2.into(),
                    in("x2") arg3.into(),
                    in("x3") arg4.into(),
                    in("x4") arg5.into(),
                    in("x5") arg6.into(),
                );
                #[cfg(target_arch = "x86_64")]
                asm!(
                    "syscall",
                    in("rax") $nr,
                    in("rdi") arg1.into(),
                    in("rsi") arg2.into(),
                    in("rdx") arg3.into(),
                    in("r10") arg4.into(),
                    in("r9") arg5.into(),
                    in("r8") arg6.into(),
                );
                #[cfg(not(any(target_arch = "aarch64", target_arch = "x86_64")))]
                compile_error!("not implemented");
            }
        }
    }
}
```

Finally, we'll implement the system calls:

```rust
#[cfg(target_arch = "x86_64")]
syscall0!(exit, 60);
#[cfg(target_arch = "x86_64")]
syscall3!(write, 1);

fn main() {
    #[cfg(target_arch = "x86_64")]
    let string = "Hello x86\n";

    // the same as before
}
```

And this time, if run on an `x86_64` linux machine, you should see the following when running: `Hello x86`.

## Conclusions

That wasn't so bad, just like the last blog post -- but it was also much easier, and you wouldn't have to remember the magic defines that are compiler dependent. As well, `cfg` attributes are extremely powerful -- much better than C defines because they're caught for you at compile time, and there are a bunch of useful ones already predefined.
