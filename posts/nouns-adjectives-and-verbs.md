---
title: "Nouns Adjectives and Verbs"
date: 2020-07-03T19:33:54-04:00
draft: true
---

Programming is similar to written language; there are nouns (structs, values), adjectives (types), and verbs (functions). These constructs exist in most statically typed languages. We'll take some examples from C in order and build our way up to features in other languages.

## Nouns

At a basic level, nouns would be values like the value `5`, or the string `"hello"`. Nouns encapsulate state, which is a collection of data that a program keeps track of during its lifetime. It would be hard to imagine programming without nouns; verbs and adjectives operate on nouns -- so without nouns, we can't build anything upon them.

## Adjectives

Adjectives describe nouns. This is most similar to typing in programming languages. The type helps describe the noun, telling us what kind of noun we have. Maybe the noun is a thing (value), place (pointer), or an idea (a user defined struct).

## Verbs

Verbs do something to nouns. There are some operators that change a noun, like the mathematical operators, and functions, which take a noun and either change that noun or output a new noun, based on the old noun.

## NounAdjectiveVerbs

in statically typed languages, we have adjective-noun-verb thinking. We first want to make sure we have the correct types, and the correct values for that type, and we operate on that value with functions. This is all fine and dandy in C -- your nouns can have nouns inside of them (structs have nouns), but they can't have verbs (functions). This works ok, but has limitations -- it becomes painful to code in an object oriented style because you need to add function pointers to your structs to create methods. C++ does this really well; you can write in a procedural style or in an object oriented style easily with improved readability. Java, unfortunately, gets this wrong.

In Java, everything must be an object; your object must have the same as your file, and if you want to do something, you must create a noun with a verb inside it first.

If you look at this code example, you'll notice this pattern; we create a prototype of the class Hello, then we create a function inside of that called main, and inside of that we call a function that logs to the console.

```{.java .numberLines}
// Hello.java
public class Hello {
  public static void main(String[] args) {
    System.out.println("Hello");
  }
}
```

We need a noun, then a verb, then another verb to do what we need here.

In C, of course, it would look something like this:

```{.c .numberLines}
#include <stdio.h>

int main() {
  printf("Hello World");
}
```

We have a verb (our main function) that calls a verb (function) on a noun ("Hello World").

If you notice, there's one less layer of indirection. This is easier to understand.

In a higher level language, the difference is more pronounced. Here's the same example in ruby.

```{.ruby .numberLines}
puts "Hello World"
```

All we need to do is call a function that takes a value of "Hello World" and operates on it. No higher level verb for our verb here. Just one verb. This is a great example of giving the programmer more power, since we're being very clear with our intent here. There are no adjectives, so we don't use them. There's no need for a noun, since all we want to do is express a noun's usage.
