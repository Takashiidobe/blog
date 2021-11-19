---
title: "Framework Maturity"
date: 2020-06-25T16:32:17-04:00
draft: true
---

Software engineers often talk about the _maturity_ of a framework or library often. This is a bit of a moving target, and depends on who you ask; is React considered to be mature? I would say so, since in the past five years it has gone from relatively unused to the most common library for frontend development. But a library like deno, which hit 1.0 in May of this year, would not qualify as mature. This is a fair axis to judge software projects on, but it leaves a lot to be desired. Semantic versioning tries to rectify this by having a clear distinction between usability of releases; anything below a version of 1.0 is not production ready, and anything above that is production ready. But being production ready isn't mature, and leaves us at square one. Is a project that released version 2.0 mature? version 6.0? Semver doesn't tell us that. Instead, I think we should split this axis into two different factors, robustness and impact.

Ruby on rails is now 15 years old; it recently reached version 6.0, and ruby is now on 2.7. Neither ruby nor rails have changed much in the past 5 years. It is a boring technology that has matured on a rock-solid foundation. It checks all of the boxes of maturity. It is also robust, has secure defaults, and catapulted the MVC (Model View Controller) design pattern to a household name. It is basically the perfect technology when it comes to maturity, robustness, and impact. But I'm judging the framework with hindsight; it's easy to pick the winners and gush over all the great things the winners did. So instead, we'll have some fun and bet on the mature, robust, and impactful frameworks of tomorrow.

## Predictions

I'll pick some projects that are in their infancy, and some that are production ready and bet on them being popular. I'll make a prediction for five years out, since that seems like a good timeframe.

Deno will be more popular for the client side and server side than node.

Deno is robust, has node's old creator, and lots of inspiration from good sources (go and rust), and seeks to simplify node into something that can compete with the relative simplicity of go. It has a chance to change the way we think about security in the node ecosystem, which would be a welcome change.

WebAssembly will power 10% of the top 500 sites.

WebAssembly will allow developers to run more languages than javascript on the frontend. You can use languages with a garbage collector like go, or go lower level and use a non garbage collected language like C, C++, or Rust, if you want top performance. I say only 10% of the top 500 sites because browser compatibility takes a while to catch up; when I interviewed for a firm two years ago in 2018, they said they couldn't use flexbox (which came out in 2009) because they had to support IE9. Generally people support browsers from 10 years ago, which will hamper WebAssembly's usage.

Rust will be the most popular language for high performance greenfield projects.

Not much to say here, Rust is solid, devoted to backwards compatibility, and has plenty of impact. It simplifies low level development considerably, and is a user friendly general purpose programming language. What's not to love?

Svelte will spearhead the next generation of Single Page Application frameworks.

Svelte is a compiler that compiles your .svelte files into pure javascript with little runtime cost (svelte itself always needs about 1k SLOC of javascript), which is a few kilobytes. Other than that, there is no runtime cost. Combine that with shorter syntax than react or vue, and you have a winner. I expect to see many offshoots of this approach in the future, and svelte to be the leader of the next generation of frontend apps as well.

All of the projects above are robust and have plenty of impact, but aren't mature; and yet I believe they are worth betting on, starting greenfield projects and migrating to, because they are all a categorical improvement on their predecessors. It's necessary to be a paradigm shift to be the technology that powers tomorrow, and the above have that potential.

Tesla has managed to carve itself a niche in the car manufacturing market as well, with its great marketing and categorically different thinking of car manufacturing.

As well, Scale AI does the same.

What technology will fuel tomorrow's future?
