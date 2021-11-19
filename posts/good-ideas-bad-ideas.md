---
title: "Good Ideas Bad Ideas"
date: 2020-10-02T18:25:02-05:00
draft: true
---

What ideas are bad? What ideas are good? What makes a good idea? What makes a bad idea? So many questions to answer, and that is the topic of today's blog post.

## Talking in Absolutes

Some ideas are good _absolutely_ and some ideas are bad _absolutely_. Some absolutely good ideas are things that have helped further humanity, so basically any knowledge gathering discipline you can think of, like Math, Science, Language, Social Studies. Without them we wouldn't know how to think; and unless you want to go back to being a caveman, learning how to think ain't so bad.

Likewise, there are _absolutely_ bad ideas. One might be to drive the Earth into the Sun, or blow us all up with nuclear weapons. Absolutely Bad ideas are nonnegotiably bad without a kernel of goodness to back them up. We'll consider both absolute good ideas and absolute bad ideas generally uninteresting for today, since most everyone won't disagree with these. But few things are absolutely good or absolutely bad, so we'll instead discuss ideas that are up in the air and see if we can't come to a conclusion about whether or not they're truly bad or truly good.

## The Rest of Life

Most ideas are some part good and some part bad -- we strive to find ideas that are mostly good and only a little bit bad and execute them in order to further our goals. But that's not to say that bad ideas have no merit; it is good to talk about bad ideas so we know what to avoid, a "proof by contradiction" if you will.

That's not to say that every bad idea has a good idea on the other side, nor do good ideas have a necessarily bad counterpart. But some do, and those help our understanding of the dichotomy of good and bad.

Anyway, since we're here to talk about ideas, let's find a few examples.

- Is Garbage Collection a good idea?

- Is Functional Programming a good idea?

- Is Static Typing a good idea?

We'll address these one by one.

### Garbage Collection

Yes it's a good idea! Managing memory is so 20th century. Or is it?

Garbage collection helps you by eliding ownership; in a non garbage collected language, if you ask for a resource that's not yours, you have to remember to return it, otherwise you leak memory. The garbage collector helps us by keeping track of what you borrow and returning it to where it needs to be when you're done. Simple.

Except when it's not.

Let's say you borrow a book from a friend, and then take some notes, referencing some concept explained in the textbook.

You've made a reference.

Let's say you decide to return said book to your friend, and then read your notes. Let's say they look something like this:

```
The mitocondria is the powerhouse of the cell.

There's more about mitocondria in Campbell's Biology Textbook, page 72.
```

Well we haven't learned much, and we need to have our friend's book to learn more.

In programming parlance, we have a dangling pointer.

In this story, we managed our own memory, gave it back too soon, and now if we follow the pointer, we'll go somewhere we don't expect, and _bad things_ will happen.

How do we avoid this? Well, we could have a garbage collector return our book when we don't have any references to it anymore.

But as long as we keep our notes, we'll have to keep the book. Our friend won't be very happy. Furthermore, since we're assuming that notes last forever, eventually we'll keep borrowing books, writing notes, need the book in our house, and then our house overflows with books and now we're homeless, with lots of people angry at us because we kept our memory too long.

You see, garbage collection doesn't prevent you from doing _the wrong thing_. If you choose to keep a static reference to something, it will never know when it can delete memory. It's on you to manage memory. And so garbage collection at the moment has some problems; it can't outsmart you, should you choose to do _the wrong thing_.

### Functional Programming

Functional programming? This must be good! Make programming like math again.

Programming is useful
