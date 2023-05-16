---
title: "Coding on Android"
date: 2023-05-15T22:33:07-04:00
draft: false
---

I like to tinker. No surprises there. But when my tinkering made it so my laptop wouldn't boot, I realized I'd need a plan B computer for when my laptop was out of business. The solution? My android phone.

I have a Samsung S10 phone, which is about 4 years old at this point and gets by just fine -- it has 8GB of RAM, with 8 cores, 2.84GHz processor, and 128GB of disk space. The computer I used growing up had a 200MHz processor, with 64MB of RAM, and a 2GB hard drive. Computers are really fast these days, and I was wondering how fast my phone would be as a general computing device.

Thankfully, the people at F-droid and Termux made that easy -- F-droid is an alternative app store for android, which comes with lots of goodies, including Termux, a unix terminal for your android that doesn't require root. I installed both and was off to the races. Termux allows you to create a symlink to your normal files, so you can still fetch them from the cli. I also used tailscale to quickly move files between my computer and my phone, so I could get my ssh keys, and other config files quickly onto the device.

I then got myself a c compiler and rust compiler and started writing code. My target triplet for rust is `aarch64-linux-android`, which is in tier-2 support for rust, so there would be some rough edges. There certainly were.

I tried to compile some command line utilities I had wrote for myself, like `host`, `dig`, `strace`, and others. The DNS library that the network requests relied upon had a bug that made them not compile on android. As well, `cargo binstall`, a utility which downloads binaries of rust code for you, would crash at runtime due to a DNS misconfiguration. I had to recompile the library with a feature flag turned off. But ignoring all those papercuts, it was mindblowing that a 4 year old phone that costs ~$200 these days could be "good enough" for writing code, and you could get by with a $50 or less phone for coding and still have a great experience (you'd also need a keyboard and a mouse and a USB-2 to USB-3 converter so you're not stuck on the default keypad, but that's not expensive, the local mart had a pair for $10).

The folks at termux do a really good job packaging code -- even though Termux Android doesn't follow the unix file specification (there is no `root` dir), they repackage debian packages to make them work anyway. And my neovim config worked flawlessly on the phone. It was a surreal experience -- and one differentiator to apple, who locks down their devices a lot more.

I even tried briefly hosting my own website and other services on the internet from my phone by using tailscale. That worked flawlessly, and I'm sure my phone could serve thousands of concurrent visitors.

The experience made me think of two things: Do I really need a laptop these days? I'll keep mine around for tinkering, but a phone is just about good enough -- with a USB-C monitor that can accept a keyboard and mouse, you could have a desktop setup for your phone, even with just one USB-C port. And a phone just fits in your pocket, with a great battery life, so you can take it on the go.

In sum, coding on my phone was a delightful experience. In fact, I liked it so much, I decided to write this post on my phone and build my blog on my phone and serve it from there. Given the backdrop of tech doom these days, it's hard to find any tech news to feel happy about -- but Termux + Android is so good that it's mindblowing. If anything, I'm glad that computing has gotten so cheap -- I'm sure there's lots of young people learning how to code on hardware just like this, and that's something that brings a smile to my face.
