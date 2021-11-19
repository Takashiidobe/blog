---
title: "Const Correctness"
date: 2021-05-17T19:32:39-04:00
draft: false
---

Const correctness means marking all items you can `const` to prevent unwanted mutation.
Let's say you want to grab a few options from a `settings` map that you've created.

Let's say you want the time to live value and the created at from a map.

Does this compile?

```{.cpp .numberLines}
void setTimeToLive(int ttl) {/* implementation here */}
void setCreatedAt(int createdAt) {/* implementation here */}

void getOptions(const std::map<const char*, int> &m) noexcept {
  const auto ttl = m["ttl"];
  const auto createdAt = m["createdAt"];
  setTimeToLive(ttl);
  setCreatedAt(createdAt);
}
```

Nope: since `map[]` will insert in the case that it doesn't find a matching key, this doesn't compile. We can't insert into a map marked const.

Let's say we didn't mark the map as `const`:

```{.cpp .numberLines}
void setTimeToLive(int ttl) {/* implementation here */}
void setCreatedAt(int createdAt) {/* implementation here */}

void getOptions(std::map<const char*, int> &m) noexcept {
  const auto ttl = m["tttl"]; // oops, typo
  const auto createdAt = m["createdAt"];
  setTimeToLive(ttl);
  setCreatedAt(createdAt);
}
```

This compiles now, but oh no, what's the value of ttl? `0`. When we access a map's key that doesn't exist, we get some default value. In our case, a value of 0.

So we're at a crossroads. We want our code to compile, be correct, and still allow the map to be `const`.

Let's let that happen:

```{.cpp .numberLines}
void setTimeToLive(int ttl) {/* implementation here */}
void setCreatedAt(int createdAt) {/* implementation here */}

void getOptions(const std::map<const char*, int> &m) {
  const auto ttl = m.at("tttl"); // oops, typo
  const auto createdAt = m.at("createdAt");
  setTimeToLive(ttl);
  setCreatedAt(createdAt);
}
```

We replace `map::[]` with `map::at`. `map::at` does a checked get in the map. If it doesn't find the key, it throws an exception.

We remove our `noexcept` from the function because this function can throw and we move on with our lives.

Const correctness saves lives.
