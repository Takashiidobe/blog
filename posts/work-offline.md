---
title: "Work Offline"
date: 2021-10-07T20:43:45-05:00
draft: false
---

In my last post, I discussed the tradeoffs of various languages with regards to software longevity -- I wanted to pick a language to use that would make long lasting software.

In this post, I want to discuss working offline -- why that interleaves with the choice of language to use, and how to use tooling to make that accessible.

Joe Nelson, of PostgREST fame, wrote a series of posts that resonated with me -- starting with ["Going 'Write Only'"](https://begriffs.com/posts/2015-04-20-going-write-only.html) where he starts off with quoting Joey Hess, a person who "Lives in a cabin and programs Haskell on a drastically under-powered netbook", where he harvests all of his electricity from the sun, and works using a distributed workflow, much like a git workflow.

He then goes on to explain his motivation of going "write-only" thusly:

> These people’s thoughts are not idle for me. They contain a reproach, a warning that one can be very busy and yet do unproductive things, hamartia. I want to focus on doing the right thing. Actually focus is the wrong word. Focusing my thoughts would imply the same thoughts but sharper, whereas I want to change the way I think.

He then went on to publish more blog posts focused on creating software that lasts:

- [Good books for deep hacks](https://begriffs.com/posts/2017-04-13-longterm-computing-reading.html)
- [Inside the C Standard Library](https://begriffs.com/posts/2019-01-19-inside-c-standard-lib.html)
- [Tips for stable and portable Software](https://begriffs.com/posts/2020-08-31-portable-stable-software.html)
- [Dynamic linking best practices](https://begriffs.com/posts/2021-07-04-shared-libraries.html)

Which are all great reads, and inspired me to write this post about how I work offline, and what I use to make that happen.

## Tools of the Trade

### [Git](https://git-scm.com/)

It's a no-brainer to use git for this kind of workflow. You can go offline for weeks at a time, hacking away at your branch, and when you're back online, merge back to the main branch, fetch what you missed, and go back to hacking away offline. Since you have a copy of all the history of the repo on your hard disk, if you need to look at changes from the past, you can do just that. Git enables this workflow, while other centralized systems require constant connectivity.

### [Man Pages](https://www.kernel.org/doc/man-pages/)

Man pages (and info pages) predate the internet, so of course they work well offline. Unfortunately for Mac, Man pages are pretty sparse (basically scavenged off of old BSD manuals), and they aren't always the most descriptive when it comes to using cli tools, so I tend to use `tldr` for that case.

To pay it forward, I tend to bundle man pages with utilities that I make, like `rvim` or `simplestats` on cargo, even though rust docs are more common in rust land.

### [Tldr](https://github.com/tldr-pages/tldr)

Ever remember how to use `tar`? Me neither. Tldr is a man pages complement, offering examples for cli applications just by typing `tldr $keyword`. I personally really like it, because it's like having a concise stackoverflow at your fingertips.

### [ZIM files](https://wiki.openzim.org/wiki/OpenZIM)

When I tell people about working offline, they ask "but what about X website?". Well, if you want to look up a question on wikipedia or stackoverflow, you'd surely need online access, right?

That's where ZIM files come in -- offline archives of whole websites. The kiwix project (sponsored by wikipedia) offers downloads and torrents for ZIM files for sites like wikipedia and stackoverflow, which you can wholesale download over an internet connection, and then search through to your hearts content. So if you ever forget how to reverse a linked list in your favorite language, you can search through stackoverflow to find out.

- <https://dumps.wikimedia.org/other/kiwix/zim/wikipedia/>
- <https://ftp.fau.de/kiwix/zim/stack_exchange/>

You can also download wikipedia's own ZIM file archiver and archive other sites that you like.

### [DevDocs](https://devdocs.io/)

Not all languages/projects have offline documentation, but most of them have documentation on the web. DevDocs is a project that allows you to download and search through that documentation in a convenient way offline. Every time you get back online, you can sync the documentation of the projects you like to follow. Nifty.

### E-books

E-Books are really great too, in both PDF and epub format. You can keep a copy of them on your hard disk and search through them too without going to the internet.

### Papers

[Arxiv](https://arxiv.org/) is a repository of open access articles in the sciences and maths. You can download papers off there for free, and read them at your leisure. There's a treasure trove of papers to read!

### [Rustup + Cargo](https://www.rust-lang.org/learn)

Rust has a strong focus on offline work -- cargo allows you to turn docstring comments into HTML documentation with search, and `rustup` comes with its own offline documentation, by virtue of `rustup docs`.

Cargo also allows one to force offline mode by adding the `--offline` command line flag -- this forces cargo to use downloaded crates instead of going to `crates.io`.

## Hardware

Currently, I work off of a Macbook pro 2017, which only has 128GB of hard disk space. If I want to supplant that with extra hard disk space, I have an external SSD that I carry around with me (with ZIM files for offline use). That being said, it is getting a bit old in 2022, and I may replace it in the coming years for a [framework laptop](https://frame.work), as the company is very devoted to right to repair.
