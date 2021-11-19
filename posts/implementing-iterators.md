---
title: "Implementing Iterators"
date: 2021-09-18T21:41:43-05:00
draft: false 
---

Let's talk about implementing iterators: a way to visit every item in a collection. We'll use C as an implementation language because it's simpler than other languages, and we'll implement C++'s iterator API. This is the same in most mainstream programming languages, like Rust, C++, Python, Ruby, JavaScript, Java, C#, and PHP, with a few small implementation differences.

## The API

The API we'll create is simple. A `int* next(int* it)` function that takes an iterator and returns its next element, or a `NULL` pointer if nothing comes next, and a `bool has_next(int* it)` that returns `true` if it has a next item, or `false` if it does not.

The C++ iterator API needs a few functions that give you an iterator to a collection. These are called `begin()` and `end()`, which return a pointer to the first item in the collection, and one past the end of the collection. This is a dangerous API, since if we dereference `end()` we automatically cause Undefined Behavior, but our APIs become a bit cleaner. Tradeoffs, I guess. 

We'll elide the details of begin in our example and implement it ourselves.

Let's start by defining our collection: an array of ints from 1 - 5.

```{.c .numberLines} 
int items[] = {1, 2, 3, 4, 5};
```

Let's say we want to print them: no need for iterators, of course. 

```{.c .numberLines} 
#include <stdio.h>

int items[] = {1, 2, 3, 4, 5};

int main(void) {
    for (int i = 0; i < 5; i++) 
        printf("%d ", items[i]);  
}
```

But we have to initialize and increment a variable and use it as an index to our collection... We want a clearer way of expressing a loop through all the items in a collection, and that's where iterators come in.

Let's start by defining the begin and end iterators.

```{.c .numberLines} 
int* begin = &items[0];
int* end = &items[5];
```

Remember, the begin points to the first item of the collection, and end points to one past the end. We can't dereference end, so keep that in mind.

Now, to create the `next()` function, we want to take an iterator and move to the next item if we aren't already at the end iterator.

Let's do that:

```{.c .numberLines} 
int* next(int* it) {
    if (it != end) 
        return it + sizeof(int);
    return NULL;
}
```

Since we know that our iterator is an (int) pointer, we want to increment the iterator four bytes (the result of sizeof(int) on my computer). This works, but there's a shorthand that most C compilers will let you do, called pointer arithmetic. In this case, the compiler knows that this is an int pointer, and so it's overloaded additions and subtractions to move forward and backwards by the sizeof an int. 

We can rewrite the above as:

```{.c .numberLines} 
int* next(int* it) {
    if (it != end) 
        return ++it;
    return NULL;
}
```

Next, we want to write `has_next`. `has_next` should return a `bool` `true` if the iterator can be incremented, or `false` if not. We know that an iterator has a next item if it's not in the last item in the collection, which is just before the end pointer. Thus, we can define `has_next` thusly:

```{.c .numberLines} 
int has_next(int* it) {
    return it != end - 1;
}
```

Let's use our iterators thus far to traverse our collection:

```{.c .numberLines} 
#include <stdio.h>

int items[] = {1, 2, 3, 4, 5};

int* begin = &items[0];
int* end = &items[5];

int* next(int* it) {
    if (it != end) 
        return ++it;
    return NULL;
}

int has_next(int* it) {
    return it != end - 1;
}

int main(void) {
    puts("Printing forwards");
    int* it = begin;
    while (it != end) {
        printf("%d has next? ", *it);
        puts(has_next(it) ? "true" : "false");
        it = next(it);
    }
}
```

This should print out:

```{.bash .numberLines} 
Printing forwards
1 has next? true
2 has next? true
3 has next? true
4 has next? true
5 has next? false
```

## Why use Iterators?

If this seems like a lot of ceremony for iterating through an array, it is. It's totally unnecessary. It gives us nothing more powerful than what a raw for loop would give us. But what happens if our collection isn't linear? What happens if we traverse a sorted map, or a graph? 

With a for loop, we must ask the caller to understand how the data structure is implemented. With an iterator, we can provide a definition of next, and has next, and the user can call it without knowing **anything about the underlying collection** outside of the fact that it is iterable. 

This allows us to wrap graphs, trees, hash tables, ranges (finite and infinite), and circular data structures in a friendly API for our users. 

As well, language features allow us to reward usage of iterators by making syntax more terse: In C++, Rust, Java, C#, Ruby, Python, and JavaScript, if you implement the iterable API in each language, you can do something along these lines:

```
for (item in collection)
  do something to item
```

And the language takes care of the rest. In C, we can't do that, but in other languages, the language gives us some reward for doing so for our own types, as our types get to behave like library defined types.

## Next Steps

Now that we can implement iterators in C, try giving it a shot in your favorite language and seeing what the iterator protocol is for it. It's loads of fun, I swear.

I tried it myself in C when writing a resizable array type too:

```{.c .numberLines} 
typedef struct Vector {
  size_t len;
  size_t capacity;
  int *items;
} Vector;

// Allow the user to set their own alloc/free
static void *(*__vector_malloc)(size_t) = malloc;
static void *(*__vector_realloc)(void *, size_t) = realloc;
static void (*__vector_free)(void *) = free;

void vector_set_alloc(void *(malloc)(size_t), void *(realloc)(void *, size_t),
                      void (*free)(void *)) {
  __vector_malloc = malloc;
  __vector_realloc = realloc;
  __vector_free = free;
}

Vector *vector_new(const size_t len, ...) {
  Vector *v = __vector_malloc(sizeof(Vector));
  int capacity = 8;
  capacity = max(pow(2, ceil(log(len) / log(2))), capacity);

  v->items = __vector_malloc(sizeof(int) * capacity);
  v->len = len;
  v->capacity = capacity;

  if (len > 0) {
    va_list argp;
    va_start(argp, len);

    for (size_t i = 0; i < len; i++) {
      v->items[i] = va_arg(argp, int);
    }

    va_end(argp);
  }

  return v;
}

void vector_free(Vector *v) {
  __vector_free(v->items);
  __vector_free(v);
}

int vector_get(Vector *v, size_t index) {
  assert(index >= 0 && index < v->len);
  return v->items[index];
}

void vector_set(Vector *v, size_t index, int val) {
  assert(index >= 0 && index < v->len);
  v->items[index] = val;
}

int vector_empty(Vector *v) { return v->len == 0; }

void vector_push(Vector *v, int val) {
  if (v->len == v->capacity) {
    v->capacity *= 2;
    v->items = __vector_realloc(v->items, sizeof(int) * v->capacity);
  }
  v->items[v->len] = val;
  v->len++;
}

int *vector_begin(Vector *v) { return &v->items[0]; }

int *vector_end(Vector *v) { return &v->items[v->len]; }

int *vector_next(Vector *v, int *it) {
  if (it != vector_end(v))
    return ++it;
  return NULL;
}

void vector_for_each(Vector *v, int (*fn)(int)) {
  for (int i = 0; i < v->len; i++) {
    v->items[i] = (*fn)(v->items[i]);
  }
}

int vector_pop(Vector *v) {
  assert(v->len > 0);
  int top = v->items[v->len - 1];
  v->len--;
  return top;
}
```

