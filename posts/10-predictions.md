---
title: "10 Predictions"
date: 2019-12-26T19:56:17-05:00
draft: false
---

In a few more days, the 2010s will be over. Lots has changed in the programming world -- Java is no longer king, but JavaScript, being the most popular language (according to stack overflow) for 7 years straight. NoSQL databases like MongoDB, Redis, and Cassandra have become exceedingly popular, as well as front end web technologies such as Angular, React, and Vue. Kotlin has become the preferred language for Android development, along with Swift for iOS. SaaS companies are ubiquitous, and Marc Andreessen's prediction of "software eating the world" rings even more true today.

Let's hope that the 20s are an even wilder ride for software development, and to that end, here I've decided to compile ten predictions for the next decade as a fun little exercise. As a reader of this article, I encourage you to do the same (I'm looking forward to seeing how our predictions are different or similar!)

Most of these predictions will be wildly incorrect, but I think this is a good excuse to think about what could be coming in the future.

## 1. Self-driving cars will still be two years out

Before anyone asks, I'm talking about level 5 meaning fully autonomous, you could take a nap in the backseat of the car with no driver autonomous. There is a lot of interest in this space, and for good reason -- Large companies like Uber, Lyft, Waymo, and Tesla have been researching self driving cars for the good part of this decade. There are many technical concerns regarding self-driving cars, but I'm actually fairly sure they'll be solved this decade. Legality is a huge gray area. Should self-driving cars never have an accident? If that blocks general availability, self-driving cars will never make it on the road. But if the government allows self-driving cars as long as they have less accidents than human drivers, I think there's a shot they make it this decade. But I think the real problem is that regulation will be lagging behind.

## 2. Rust will become a top 10 language in popularity

According to 2019's Stack overflow's developer survey, the tenth most popular language is TypeScript, which has 21.2% of respondents professing usage. Right above that is C++ at 23.5%, and right below is C at 20.6%. Rust is currently at 3.2%, sitting just below Scala. Of the ten languages, Typescript is the only one younger than a decade, but it has already edged out C in popularity. Rust is the only language that can save us from C and C++ supremacy in high performance computing. It has a couple of famous backers (like Mozilla and Amazon), and it has won most loved language for 4 years running on Stack Overflow. Allowing access to low level computing without unsafe abstractions is a real treat. Every generation of programmers flocks to a new way of doing computing -- C saved us from assembly, and C++ followed to tack on object oriented programming and RAII. Java popularized garbage collection, and languages such as Javascript, Python, and Ruby added higher level functional abstractions to the mainstream. I think this next decade will see the rise of Swift, Kotlin, Go, and Rust to the top 10 of languages.

## 3. WebAssembly will kill JavaScript and Desktop Apps

I don't mean kill kill, like how C did away with Fortran. I expect to see JavaScript as a top 5 language still by the end of this decade, but I think WASM is too much of a game changer to ignore. Applications with higher performance requirements are gated from the web because JavaScript is the only front-end programming language -- you simply can't have a garbage collected interpreted language be high performance. WebAssembly changes all of that. Compile Rust, Go, C or C++ for the front end. Games, exiled to desktops after the death of flash, can come back to the web. Developers with high CPU requirements (like AI/ML apps) will most likely find their home on the web this decade. I expect something similar to npm popping up, but for all kinds of packages in all kinds of languages, widening the range of the web.

## 4. JSON will be replaced with a Typed Transfer Protocol

JSON has been around for 20 years -- but I don't expect it to be popular for another 20. While I enjoy working with JSON APIs, I think that choosing a JavaScript based transfer protocol is a double edged sword. Sure, it rose in popularity because it's just like Javascript, but JavaScript is fast and loose, something not all programmers appreciate. Tools to facilitate typing and strictness have popped up for JSON, but sometimes it's better to start from the ground up. I expect something like YAML with strict typing becoming more of the standard by 2030.

## 5. Functional Programming will finally become popular

Programming in a functional style has become all the rage recently, but people still haven't adopted functional languages into their toolkit. Of the three tenets of functional programming, most mainstream languages have accepted two, functions as first class citizens, and stronger typing. Immutability is hard to implement if all of your data structures are mutable, so that's a non-starter. I just want to be able to talk about algebraic data types at a meetup without being an outcast, darn it!

## 6. Microservice hype will wear off

This one will probably seem crazy to half of the readers, and obvious to half of the readers. Microservices are great because they encourage looser coupling. Unfortunately, looser coupling also requires more code. And the worst thing you could do to your codebase is increase the amount of code it has. If monoliths create tech debt gradually by entangling everything in their grasp, the sheer amount of code microservices introduce will blanket your entire organization.

## 7. Facebook will no longer be a top 10 company

Facebook made one good product 15 years ago. The other two products driving most of their profits, Instagram and WhatsApp were acquisitions. Among the youth, Facebook is unhip and ancient. You know, just like commodores are artifacts of a bygone epoch. Zuckerberg is smart, but I don't think good acquisitions (which saved Facebook this decade) will save them the next decade. We'll see though.

## 8. An AI startup will become this decade's hottest startup

Last decade's hottest startups, like Uber, or Lyft, or AirBnB created the gig economy. I expect AI to try to coax the gig economy into its coffin.

## 9. Blockchain will be this decade's beanie babies

Blockchain has been gaining ubiquity as a secure new way to exchange funds, but I don't see it taking off just yet - It strikes me as an idea that is too early for its current decade.

## 10. You and I will host our apps on a new cloud provider (read. not AWS)

AWS became _extremely_ popular this decade - and I don't expect the service to die this decade. While it's great for enterprise by thinning the IT department, it's not made for you and me. It's confusing, for one, with configuration hiding behind every corner, ready to jump out and spook you. Oh yeah, and it costs a lot.
