#!/usr/bin/env python3

import os

import frontmatter

POSTS_DIR = "posts"
OUT_DIR = "site/gen"


def sorted_posts():
    arr = []
    for filename in os.listdir(POSTS_DIR):
        with open(os.path.join(POSTS_DIR, filename)) as f:
            metadata, _ = frontmatter.parse(f.read())
        if metadata.get("draft") == False:
            arr.append((metadata["date"].timestamp(), filename))
    arr.sort(reverse=True)
    return arr


def main():
    posts = sorted_posts()
    for i, (_, filename) in enumerate(posts):
        neighbors = []
        if i - 1 >= 0:
            neighbors.append(os.path.join(POSTS_DIR, posts[i - 1][1]))
        if i + 1 < len(posts):
            neighbors.append(os.path.join(POSTS_DIR, posts[i + 1][1]))
        if not neighbors:
            continue
        target = os.path.join(OUT_DIR, filename[:-3] + ".html")
        print(f"{target}: {' '.join(neighbors)}")


if __name__ == "__main__":
    main()
