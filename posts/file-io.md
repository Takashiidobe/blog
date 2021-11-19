---
title: "File Io"
date: 2021-05-19T16:41:02-04:00
draft: false
---

File I/O is slow: but how slow is it really? Are there any ways we can make it faster? Let's find out!

First let's start out by writing the character `a` to a file in python:

```{.python .numberLines}
import timeit


def test():
    with open(f'output.txt', 'w+') as f:
        f.write('a')


if __name__ == "__main__":
    print(
        f'This took {timeit.timeit("test()", globals=locals(), number=1)} seconds.')
```

On my machine, this prints out:

```{.sh .numberLines}
This took 0.0002999180000000032 seconds.
```

Makes sense. Since it's hard to look at such small numbers, let's bump our number of repetitions up to `10000`.

```{.python .numberLines}
import timeit


def test():
    with open(f'output.txt', 'w+') as f:
        f.write('a')


if __name__ == "__main__":
    print(
        f'This took {timeit.timeit("test()", globals=locals(), number=10000)} seconds.')
```

On my machine, this prints out:

```{.sh .numberLines}
This took 4.582478715000001 seconds.
```

Let's try something similar but in memory. Let's add the string `a` to an empty string and return it:

```{.python .numberLines}
import timeit


def test():
    s = ''
    s += 'a'
    return s


if __name__ == "__main__":
    print(
        f'This took {timeit.timeit("test()", globals=locals(), number=10000)} seconds.')
```

On my machine, this prints out:

```{.sh .numberLines}
This took 0.0009243260000000031 seconds.
```

Doing some math, writing to a file 10000 times is 5000x slower than writing to a string 10000 times in memory.

So our intuition (and our Operating Systems textbooks) are correct. Let's dig deeper to see if we can find anything else.

## Intuition

Since all we're doing is opening a file, writing to it, closing the file 10000 times, maybe there's some way to speed up this operation.

Let's build a mental model for how python writes to a file:

1. Open `output.txt`.
2. Write the character `a` to `output.txt`.
3. Close the file.

## Suggestion 1:

Since we're opening and closing the same file, what if we had some abstraction that represented the file? Let's say we had some integer that would represent the file (a file descriptor) and we kept track of its state inside of our program. Whenever we need to save our changes to disk, we notify the OS.

So instead of doing:

```{.python .numberLines}
repeat 10000 times:
  open `output.txt`
  clear the contents of `output.txt`
  write `a` to output.txt
  close `output.txt`
```

Which would require us to open the same file 10000 times:

We try this:

```
file_contents = {}
file_contents['output.txt'] = 'a'
open file
clear the contents of `output.txt`
write file_contents['output.txt'] to `output.txt`
close `output.txt`
```

Which would only require 1 call to the OS to open the file, 1 call to the OS to write to the file, and 1 call to the OS to close the file.

Python does this to some degree out of the box: the interpreter keeps a dictionary of file_descriptor -> changes and when it deems necessary, it gives the file changes to the OS.

To make python commit its buffer to the OS, use the `flush()` function.

## Suggestion 2:

What if the OS had a cache too? Since there are many processes trying to access the OS' resources, the OS has a chance to reconcile file writes and batch them in a way that is more efficient.

Let's say we ran the same python program twice at exactly the same time. If we only employed caching at the python level, we'd have to write to the same file twice with the character `a`. Of course, the OS can reconcile those changes and make it so there's only 1 open-write-close cycle required.

It turns out both of these suggestions are implemented.

To force the OS to propagate a change, you can use the `os.fsync(f.fileno())` function. When called, python asks the OS persist the changes in file descriptor `f` to disk.
