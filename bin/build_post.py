#!/usr/bin/env python3


import os
import subprocess
import sys

import frontmatter

POSTS_DIR = "posts"


def sorted_posts():
    arr = []
    for filename in os.listdir(POSTS_DIR):
        with open(os.path.join(POSTS_DIR, filename)) as f:
            metadata, _ = frontmatter.parse(f.read())
        if metadata.get("draft") == False:
            title = metadata.get("title", filename[:-3])
            arr.append((metadata["date"].timestamp(), filename, title))
    arr.sort(reverse=True)
    return arr


def main():
    src, dst, *pandoc_args = sys.argv[1:]
    filename = os.path.basename(src)
    posts = sorted_posts()
    idx = next(i for i, (_, fn, _) in enumerate(posts) if fn == filename)

    nav_args = []
    if idx - 1 >= 0:
        _, prev_fn, prev_title = posts[idx - 1]
        nav_args += ["--metadata", f"prev-url={prev_fn[:-3]}.html"]
        nav_args += ["--metadata", f"prev-title={prev_title}"]
    if idx + 1 < len(posts):
        _, next_fn, next_title = posts[idx + 1]
        nav_args += ["--metadata", f"next-url={next_fn[:-3]}.html"]
        nav_args += ["--metadata", f"next-title={next_title}"]

    cmd = ["pandoc"] + pandoc_args + nav_args + ["-o", dst, src]
    subprocess.run(cmd, check=True)


if __name__ == "__main__":
    main()
