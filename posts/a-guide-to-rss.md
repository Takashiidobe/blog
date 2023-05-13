---
title: "A Guide to RSS"
date: 2023-02-08T08:15:00-05:00
draft: false
---

At the start of the year I decided to read more quality stuff instead of mindlessly doom scrolling the internet. An internet diet. I believe in discussing tools + methods to solve problems, so here are some findings I had setting up an RSS feed, reading from it, and some of the challenges along the way.

## Setup

If you're like me, you want a few things:

1. Offline reading
2. Syncing
3. Caching
4. Mobile + Terminal + Web + Desktop clients

To feasibly implement syncing across multiple devices, we'll need a server to host our RSS feed. I self-host [FreshRSS](https://github.com/FreshRSS/FreshRSS), which acts as both a web client and the server. It allows for syncing from many clients, which is great, and it has an easy docker-compose file to pull in all necessary dependencies. FreshRSS exposes an API as well as a Google Reader compatible API, which most clients support. This supports authentication, which is a nice feature for locking down your server.

Finally, we'll need clients that implement offline reading and heavy caching for good performance, for mobile, the terminal, and the desktop.

I use an Samsung S10 as my phone, which runs android. The app I use on mobile is FeedMe, hooked up to my FreshRSS server through the Google Reader API. This heavily caches and works well offline, so on the go I can read some feeds.

For a desktop client, I run a linux laptop, so I use Newsflash. Newsflash is similar to FeedMe, with support for the Google Reader API, and good offline capabilities. I tried a few other services, but they couldn't parse my large RSS feed.

For a terminal client, I use newsboat. Newsboat is a curses-based text only feed, so RSS feeds that don't send over the full article content are a bad reading experience on newsboat. To deal with this, I use `morss`, which scrapes the link provided by the RSS feed, and then generates a new RSS feed with the content of the blog included.

[morss](https://github.com/pictuga/morss) can be downloaded with `pip`.

Now you should have everything set up, and can add some feeds to your server, pull them down to your clients, and are ready to go.

But what if you're new to this RSS game, and want to read some older posts?

## Reading Older RSS Posts

Did you know that RSS can support older posts, and that blog platforms like wordpress, blogger, and blogspot have those capabilities built in? For example, let's say I wanted to read James Clear's old posts. His current feed, located at `https://jamesclear.com/feed` has 10 of his most recent blog posts. But he's published 300 more.

His blog actually has those old posts in RSS form for us, we just have to find it.

Some blog sites' RSS supports the `paged` query parameter. `paged=1` means the first page, and `paged=2` means the second page. In Jamesclear's case, we just have to binary search to find the last RSS feed supported by the website.

We could start out at `https://jamesclear.com/feed?paged=100`, realize that doesn't work, try `https://jamesclear.com/feed?paged=50`, realize that doesn't work, go to `https://jamesclear.com/feed?paged=25`, see that works, and then figure out the last page, which as of now is page 30.

We can then download all of those rss feeds with a handy dandy bash script:

```sh
#!/usr/bin/env bash

for num in $(seq 1 30); do
  wget "https://jamesclear.com/feed?paged=$num" -O $num.rss
done
```

And then we can download the 30 rss feeds.

We now have 30 rss feeds that have the content we want to read. But having to add 30 entries to our RSS client is a bit of a pain: let's aggregate them.

I wrote a little script that would batch these into feeds with 150 posts each, using `feedgen` and `feedparser`.

```python
#!/usr/bin/env python3

import feedparser
from feedgen.feed import FeedGenerator
from glob import glob

files = glob('*.rss')
file_count = len(files)
file_generators = []

for i in range((file_count // 15) + 1):
    fg = FeedGenerator()
    fg.id('https://jamesclear.com/')
    fg.title(f'James Clear Page {file_count // 15 - i + 1}')
    fg.link(href='https://jamesclear.com/')
    fg.author( {'name':'James Clear','email':'jamesclear@gmail.com'} )
    fg.link(href='https://jamesclear.com/', rel='alternate' )
    fg.logo('https://jamesclear.com/favicon.ico')
    fg.subtitle('An Easy & Proven Way to Build Good Habits & Break Bad Ones')
    fg.link(href='https://jamesclear.com/feed', rel='self' )
    fg.language('en')
    file_generators.append(fg)

for index, file_name in enumerate(files):
    file_generator_index = index // 15
    with open(file_name) as f:
        xml = f.read()
        d = feedparser.parse(xml)
        for entry in d.entries:
            fe = file_generators[file_generator_index].add_entry()
            fe.id(entry['link'])
            fe.title(entry['title'])
            fe.link(href=entry['link'])
            fe.content(entry['content'][0]['value'])
            fe.description(entry['summary'])
            fe.author(entry['authors'][0])
            fe.guid(entry['link'])
            fe.pubDate(entry['published'])

for index, fg in enumerate(reversed(file_generators)):
    fg.rss_file(f"../site/james-clear-{index + 1}.rss")
```

We can then aggregate these rss feeds into two rss feeds, and then put them in a folder. I host my RSS feeds on the web using netlify, `https://takashis-rss.netlify.app/` so that my RSS server can pull these feeds and get the content from them.

You can use any web hosting service you like, or self-host it. It's up to you, it just needs to be online for the RSS server to be able to pull down.

## What about Atom?

Not all feeds are RSS feeds, some are Atom feeds. Take https://blog.computationalcomplexity.org/ for example. Atom doesn't support the `paged` query parameter. But it supports something even better. We'll first download their feed at https://blog.computationalcomplexity.org/feeds/posts/default and open it up in a text editor. Inside, we should be able to find that it has 2980 articles, and they can be queried with a different query paramter, called `start-index`.

So https://blog.computationalcomplexity.org/feeds/posts/default?start-index=100 fetches the 100th - 125th blog post. We want to do this until we hit the 2980th article:

To do that, we edit the previous script a bit:

```sh
#!/usr/bin/env bash

for num in $(seq 1 25 2980); do
  wget "https://blog.computationalcomplexity.org/feeds/posts/default?start-index=$num" -O $num.rss
done
```

And we can fetch all the posts, and aggregate them much the same way as above.

## Rendering more content with morss

This is good enough for some feeds, but some feeds only show a little bit of content, which is undesirable for terminal readers like `newsboat`, which don't fetch the entire article, just the RSS content.

We can download `morss` with `pip` and run this script, which renders the feed with a web browser and scrapes it into an RSS feed.

```sh
#!/usr/bin/env bash

for num in $(seq 1 37); do
  LIM_ITEM=-1 MAX_ITEM=-1 morss "https://travelfreak.com/feed?paged=$num" > $num.rss
done
```

This lets us get around those pesky feeds with no content and just a link.
