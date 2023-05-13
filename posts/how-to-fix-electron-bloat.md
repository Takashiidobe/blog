---
title: "How to fix Electron Bloat"
date: 2023-04-13T09:16:57-04:00
draft: true
---

Tl;dr: No solution on how to fix electron bloat is given here, just an idea.

Work with enough programmers and you'll hear this complaint: "Electron is so bloated and slow!". And it's true -- VS Code, Slack, Teams, Skype, and other applications all use electron for cross-platform compatability. But they all bundle in a copy of chrome, weighing hundreds of megabytes. This leads to high memory usage, slow startup times, and the feeling that it was better in the old days.

They'll ask why people don't use something like QT or another GUI kit to create their applications, so it can be fast and use less memory. A company in town used to do that. Until they ran out of new developers to work on their application. But as Steve Yegge mentioned 20 years ago, Web Programming will obsolete desktop programming. And it did. So there were no new developers who wanted to work with desktop applications, and this company was forced to either wither away or embrace electron.

So of course, they did the honorable choice. They went bankrupt. Just kidding, they swapped to electron like any sane business would.

So electron is king, and we have nothing to do but watch as 500MB applications clutter our hard drive and 5 applications drive our computer to a halt. Not yet, I suppose. There are a few ideas that people have done to lower the cost of running a web browser in every app, but i'll list mine here.

## Futamura Projections

What if we could remove all the code from the browser that we didn't use? Like tree-shaking from javascript or dead-code removal in a compiled language.

Imagine you wanted a desktop application that ran only on Windows. Well, you could provide some flag, and then build a version for windows only. That removes all the other backends.

Good. But what if we went one step further, and the compiler could read our code, and realize we only used document.querySelector and addClass and removeClass, and remove all other features of chrome.

That would be nice. We could then ship a version of our code that only uses the features of chrome it needs, and then ship that to our users.

This is pretty much what GraalVM does already.
