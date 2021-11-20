---
title: "Writing Portable C"
date: 2021-11-15T18:06:09-05:00
draft: false
---

On my free time I've been hacking away on
[unix-utils](https://github.com/Takashiidobe/unix-utils), a project that
implements some common unix utilities. In order to test how portable C
really is for the average programmer, I decided to lean on open source
to see how many platforms I could target my C with. I wanted to write
the most portable code I could (that meant targeting only POSIX)
functions and using a minimalistic stdlib that tried its best to adhere
to the standards (musl). This let me write C code for about 50
targets. Let's go deeper into the background and how that was all
possible:

## POSIX and SUS

In the 70s, C was made at AT&T. In the 80s, it escaped, becoming more
popular, before eventually becoming standardized by ANSI (C89). But what
about standards for Operating Systems? Enter POSIX (the Portable
Operating System Interface), a standard for operating system interfaces.
In 1988, the first version of POSIX was released by the IEEE, which
detailed common interfaces, like Signals, pipes, and the C standard
library.

The POSIX standards were fairly minimalistic in the 80s, adding some
extensions (like real time programming) and thread extensions) in the
early 90s before being subsumed by the Austin Group, a committee that
designed the Single Unix Specification. The Austin Group has steered the
POSIX standards since 1997, creating standards like (POSIX 1997/SUS v2),
(POSIX 2001/SUS v3), and (POSIX 2008/SUS v4).

Since 2008, there have been two minor corrections to the POSIX standards
(one in 2011 and 2017), but the two most common POSIX standards in use
are POSIX 2001 and 2008, which is where we'll be directing most of our
attention to.

POSIX compliance in particular ends up being extremely important,
because most Operating Systems have at least some level of POSIX
compliance. Linux, the BSDs, Mac OS, and Windows all do to some extent.
That means that our C code can target all of them by following the
standards, which makes our code more flexible.

This is so important that GCC (GNU's C Compiler) ended up implementing a
flag that checks for strict compliance to the POSIX standard of your
choice.

In my Makefile, I have this line, which says to compile my code strictly
according to the standard.

```{.make .numberLines}
CFLAGS = -std=c99 -D_POSIX_C_SOURCE=200809L
```

Since I wrote the first draft of my utilities on a Mac OS computer with
no POSIX compatibility flags, you can imagine there was a lot of
breakage. As to why there was so much breakage, well, that requires
another history lesson.

## GCC vs MUSL

In the 80s, the Free Software Foundation (FSF) wanted to create the
ideal "Free" programming environment. To do so, they were going to start
from the top-down, by implementing the user space (a C compiler, a
shell, the POSIX shell utilities, etc), and then build an OS kernel (GNU
Hurd). GNU succeeded at one part of their mission, by providing the most
common userspace tools to date (GCC, Bash, and the GNU utils). However,
GNU's kernel lost out to Linux, and the rest is history.

Linux started out only supporting GCC tools for its userspace, but now
it can support a wide variety of C standard libraries (libc for short).
One of those ends up being Musl, the standard library of this article.

The choice of standard library would end up being entirely
inconsequential if not for one detail: Musl supports static linking, and
GCC does not.

Sure GCC supports a lot of non-standard extensions, and sure GCC
executables are more bloaty than their musl counterparts, but static
linking lets us execute our binaries without having installed a libc on
the platform.

That means our code can reach even more users!

Much blood has been spilt on static vs dynamic linking, so I will spare
you the carnage by simply saying that static linking tends to be more
convenient for the end user (they require less dependencies on their
side to run the code), which is good for us, the application builders.

## What Sacrifices were made?

### How do you make static binaries?

Going back to building some unix utilities, I downloaded a musl-gcc
compiler, logged into my linux VM and started compiling.

The first issue I ran into was that musl-gcc didn't compile static
binaries.

I added the flag `-static` to my build, but `file` and `ldd` ended up
telling me that my binary was still dynamically linked.

I dug through troves of documentation. Eventually, I discovered that it
wasn't enough just to provide the `-static` flag, because GCC can ignore
it. You have to provide another flag, `--static` as well. Oh, and if
that wasn't enough, that still didn't compile static binaries. You had
to disable `pie`, or `position independent executables` with the flag
`-no-pie` as well.

Finally, I had compiled a hello world binary statically. Time to move
on!

### Don't name your functions `_init`

I then tried to compile my utilities. I wanted to decrease duplication
so I wrote a header file with a function called `_init`. This ended up
causing a duplicate symbol error (musl defines this function in crti.o
first).

Of course, GCC never complained, so I had to rename this function.

### `getopt_long` doesn't exist

Next up, `getopt_long` (Get options with long flags) isn't POSIX
standard. Unshocking. POSIX only specifies the normal `getopt`, which
supports short options only. Long options like `--file` or `--color` are
a GNUism.

I ended up finding a copy of `getopt_long` online and rewriting my
header file includes for my utilities.

### Sysctl isn't standard

Next up, I had a compiler error where my implementation of `uptime`
failed to compile. `<sys/sysctl.h>` is a Macism, and not part of POSIX.
Linux offers it up in `<linux/sysctl.h>` for convenience, but as its
name might indicate, it's not portable.

Next!

### lstat has optional fields

In my implementation of stat, I used the functions `major`, `minor` and
`ctime`, none of which are POSIX compliant. They're useful on mac os, so
I can gate them behind an `__APPLE__` macro, but that makes the code
less succinct. Oh well.

### `NI_MAXHOST` isn't defined

As an oddity, musl doesn't define `NI_MAXHOST` at all. This is useful
for `dig`, which returns the ip address for a given address. I ended up
defining it if it wasn't already defined.

## Getting the Toolchains

With all these changes made, our code will now compile for Linux + musl,
thankfully. The next problem was actually getting our toolchains.

Luckily, after some googling, I found out about <musl.cc>, a website
which releases versions of musl-gcc toolchains.

Now, since I didn't want to create an undue amount of load onto this
website, I created a mirror of it:
<https://github.com/Takashiidobe/muslcc>.

Next, I had to create a github action that would fetch the compiler
required, set it up properly, compile all of the binaries, strip the
debug information, tar them into one directory, and release them on a
push to tags. Phew!

This part turned out to be a lot of guesswork and letting it run, so
I'll leave the final results here:

<https://github.com/Takashiidobe/unix-utils/blob/master/.github/workflows/release.yml>

And the repo here:

<https://github.com/Takashiidobe/unix-utils>

## In Short

It's amazing that you can write code that targets so many
architectures, and compile to them easily, all for free, with the power
of open source (and Microsoft's wallet, thanks Github Actions).

With this, I was able to build for 52 architectures and release code for
them (I ended up adding in support for x86\_64 Darwin and arm64 Darwin).

Viva portable code.
