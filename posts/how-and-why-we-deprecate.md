---
title: "How and why we deprecate"
date: 2021-06-07T09:59:55-04:00
draft: true
---

# How we deprecate things

When writing code that other people use, it's important to be able to deprecate code for the following reasons:

1. We've found an alternative way to do something that we think is better than the previous way.
2. The code is written in a way that it isn't correct, and can't be fixed without changing it in a non-breaking fashion.
3. The feature is extraneous, and can be done better by using some other code. 
4. We've found a better name for this code.

Let's go through the reasons:

## Alternative Methods

This is the most common kind of deprecation. Let's take the example of `std::auto_ptr` and `std::unique_ptr` in C++.

`std::auto_ptr` in C++ was introduced in C++03 as the first smart pointer in the standard library. When `auto_ptr` would go out of scope, it would call the destructor of the thing it owned.

It was the best possible unique pointer at the time, because C++ did not have move semantics. As such, the `=` operator would copy an `auto_ptr`, which is confusing to users. If a pointer is meant to uniquely own a resource, we should not be able to make copies of it, because that violates the invariant of it being unique. 

In C++, move semantics were introduced, where a `=` operator was overloaded to move what was on the right hand side to the left hand side. Therefore, the new smart pointer would to overload move semantics on a call to `=`. But since users used the `=` operator to mean copy construction, this would be a backwards incompatible change. 

Thus, the committee decided to deprecate `auto_ptr` and create a new smart pointer called `unique_ptr` that was similar in behavior, except it was not copyable.


```{.cpp .numberLines}
std::auto_ptr<Widget> p1(new Widget());
std::auto_ptr<Widget> p2 = p1; // p2 is now a copy of p1
```

```{.cpp .numberLines}
std::unique_ptr<Widget> p1(new Widget());
std::unique_ptr<Widget> p2 = p1; // this is a copy, and causes a compile time error.
```

```{.cpp .numberLines}
std::unique_ptr<Widget> p1(new Widget());
std::unique_ptr<Widget> p2 = std::move(p1); // this is a move, and thus legal. p1 is moved into p2.
```

As you can see, a correctly implemented function may require deprecation, as an alternative might emerge that is more correct. In the case of migrating from `auto_ptr` to `unique_ptr`, `unique_ptr` is simpler (since users do not have to worry about copying it accidentally, as this is disallowed by the language), more intuitive (there is only one owner for X) and less error prone.

## Fixing Correctness

Sometimes we implement code in a way that isn't correct. Either it gives you the wrong result sometimes, or maybe it causes security vulnerabilities. `gets` from C and C++ is a great example of that.

`gets` takes bytes from an arbitrary source (normally stdin) until a new line is found, and places them into a buffer of your choice. Easy, right?

Well, since `gets` doesn't allow you to specify up to how many bytes to take, you can overwrite your own address space, crashing your own program. Wonderful design.

Using `fgets` is considered better, since it takes a `size` of characters to write at max. Thus, if you correctly call `fgets` (you make your count as large as your buffer), you can't overwrite your own address space. (Of course you still have to use `fgets` properly, but we're trusting you). 

We all write bad code. Sometimes innocuous design decisions can come back to bite us. Deprecation gives us a tool to fix those mistakes.

## Extraneous Features

In C and C++, there are trigraphs which represent the following symbols:

| Trigraph | Equivalent  |
|:--------:|:-----------:|
| ??=      | #           |
| ??/      | \           |
| ??'      | ^           |
| ??(      | [           |
| ??)      | ]           |
| ??!      | \|          |
| ??<      | {           |
| ??>      | }           |
| ??-      | ~           |

Since not all keyboards might have these symbols, the standard allowed you to write these symbols with an ASCII compliant keyboard.

In the 60s, this made sense, since keyboards supported fewer characters. In 2020... Well, I haven't seen a keyboard that doesn't support `#`.

Thus, in C++17, this feature was removed, since it wasn't used anymore. Talks to deprecate this feature came in C++11.

## Better Naming

In Java, the `FontMetrics` library has two functions. One is called `getMaxDecent`, and the other is called `getMaxDescent`. 

`getMaxDecent` is a spelling error. 

As such, `getMaxDecent` has been deprecated, and users are told to use `getMaxDescent`.

Whoops. 

Spelling matters, especially for users. 

Outside of spelling mistakes, sometimes you find a better name. In Rails 6, `update_attributes` was deprecated in favor of `update`.  `update_attributes` is clearer to me, but `ActiveRecord` has other methods like `create`, which more closely align with `update`. In order to make Rails more intuitive, they've deprecated `update_attributes` in favor of `update`.

Nice.

## How we Deprecate

With all that out of the way, you're probably wondering how we should deprecate. Well, in most language, it's pretty straightforward:

### Ruby

`Kernel.warn` is used in ruby to signal deprecation. If your program is run in production, warnings are suppressed, so they don't show up. Otherwise, this method logs the message passed to it to the console.

```{.rb .numberLines}
def deprecated
  Kernel.warn "This method is deprecated, use `better_method` instead"
  better_method
end

def better_method
  42
end
```

### Java

Java has provided the `@Deprecated` annotation since Java 5 to signal deprecation.

```{.java .numberLines}
public class Example {
  @Deprecated
  public int deprecated() {
    return 42; 
  }

  public int betterMethod() {
    return 42;
  }
}
```

### C++

C++ has the `[[deprecated]]` attribute to signal deprecation.

```{.cpp .numberLines}
[[deprecated("Use betterMethod() instead.")]]
int deprecated() {
  return 42;
}

int betterMethod() {
  return 42;
}
```

## Conclusion

So we've learned why code is deprecated, and how to deprecate it in some common languages. Hopefully you can see why so much code is deprecated, and what sort of tools library writers use to signal deprecation to their users. Hopefully we can write better libraries that need fewer deprecations in the future, but also allow users to have less toil when maintaining their applications.
