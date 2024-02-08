#!/usr/bin/env python3

import frontmatter
import os

arr = []

for filename in os.listdir('./posts'):
    with open(os.path.join('./posts', filename), 'r') as f:
        metadata, _ = frontmatter.parse(f.read())
        if 'draft' in metadata and metadata['draft'] == False:
            arr.append((metadata['date'].timestamp(), os.path.join('posts', filename)))

arr.sort(reverse=True)

for item in arr:
    print(item[1])
