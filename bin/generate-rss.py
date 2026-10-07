#!/usr/bin/env python3

from datetime import timezone
from email.utils import format_datetime
from html import escape
from pathlib import Path
import re

import frontmatter


def cdata(value):
    return f"<![CDATA[{value.replace(']]>', ']]]]><![CDATA[>')}]]>"


def main():
    posts = []
    for path in Path("posts").iterdir():
        metadata, _ = frontmatter.parse(path.read_text())
        if metadata.get("draft") is False:
            posts.append((metadata["date"], path, metadata.get("title", path.stem)))
    posts.sort(key=lambda item: item[0], reverse=True)

    items = []
    for date, path, title in posts:
        page = Path("site/gen", path.stem + ".html").read_text()
        match = re.search(r"<article>\s*(.*?)\s*</article>", page, re.DOTALL)
        if match is None:
            raise ValueError(f"Could not find article in {path.stem}.html")
        pub_date = format_datetime(date.astimezone(timezone.utc))
        guid = f"https://blog/{path.stem}.html"
        items.append(
            "<item>\n"
            f"<title>{escape(str(title))}</title>\n"
            f"<pubDate>{pub_date}</pubDate>\n"
            f"<guid>{escape(guid)}</guid>\n"
            f"<description>{cdata(match.group(1))}</description>\n"
            "</item>"
        )

    print('<?xml version="1.0" encoding="UTF-8" ?>')
    print('<?xml-stylesheet href="./assets/rss.xsl" type="text/xsl"?>')
    print('<rss version="2.0">\n<channel>')
    print("<title>Takashi Idobe</title>")
    print("<link>https://takashiidobe.com</link>")
    print("<description>Thoughts on Programming</description>")
    print("\n".join(items))
    print("</channel>\n</rss>")


if __name__ == "__main__":
    main()
