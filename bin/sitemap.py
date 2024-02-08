#!/usr/bin/env python3

import glob
from pathlib import Path
from subprocess import run
import frontmatter

print('<?xml version="1.0" encoding="UTF-8"?><?xml-stylesheet type="text/xsl" href="./assets/sitemap.xsl"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
for f in glob.glob("./site/**/*.html"):
    f = f[5:]
    file_stem = Path(f).stem
    print(f"<url><loc>.{f[1:]}</loc>")
    md_file_name = f'./posts/{file_stem}.md'
    res = run(['git', 'log', '-1', '--pretty="%cd"', '--date=iso-local', md_file_name], capture_output=True)
    last_modified = res.stdout.strip().decode('utf-8')
    print(f"<lastmod>{last_modified}</lastmod>")
    with open(md_file_name, 'r') as md_file:
        metadata, _ = frontmatter.parse(md_file.read())
        if 'date' in metadata:
            published = metadata['date']
            print(f"<pubdate>\"{published}\"</pubdate>")
    print("</url>")
print("</urlset>")
