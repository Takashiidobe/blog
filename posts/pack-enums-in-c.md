---
title: "Pack Enums in C"
date: 2021-05-29T00:16:07-04:00
draft: false
---

What's the default size of enums in C?
Well it's int. We can see that by using `sizeof` in an example program:

```{.c .numberLines}
#include <stdio.h>

typedef enum Example {
    One = 1,
    Two = 2,
} Example;

int main(void) {
    printf("The size of Example is: %d\n", sizeof(Example));
}
```

Which prints out 4.

This is noted by the standard: enums should be able to hold 4-bytes.

But 4 bytes seems wasteful, especially in this case: if we have an enum with two choices, we only need a bit to represent it.

In GCC and Clang, there's support for `__attribute__` modifiers. Let's use the `((__packed__))` modifier to tell the compiler to use the smallest type it can for our enum.

```{.c .numberLines}
#include <stdio.h>

typedef enum Example {
    One = 1,
    Two = 2,
} __attribute__ ((__packed__)) Example;

int main(void) {
    printf("The size of Example is: %d\n", sizeof(Example));
}
```

Which prints out 1. (our enum is now represented by an unsigned char).

If you want to make enums more dense in memory, this is the way to go.
