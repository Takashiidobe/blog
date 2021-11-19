---
title: "pointer arithmetic"
date: 2021-06-05T14:23:49-04:00
draft: true
---

```{.cpp .numberLines}
#include <stdio.h>

int main(void) {
    int arr[5] = {1,2,3,4,5};
    int* array = arr;
    array++;

    printf("%d\n", array[0]);
}
```
