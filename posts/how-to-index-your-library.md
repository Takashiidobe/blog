---
title: "How to index your library"
date: 2023-01-23T08:34:32-05:00
draft: false
---

Books are nice. They make transferring knowledge easy, and are a way to record things for the future. What's not nice is searching through them. Who uses a glossary nowadays?

Another problem: my collection of books is too large to put in my tiny apartment:

```sh
$ find . -type f -name "*.pdf" | wc -l
223
```

But if I have these books, I might as well index them, so I can search for them quickly:

First, since pdfs are binary, we'll have to extract their textual content to a file:

```sh
#!/usr/bin/env bash

title_case() {
  sed 's/.*/\L&/; s/[a-z]*/\u&/g' <<< $1 | tr '-' ' '
}

for f in $(find . -type f -name "*.pdf"); do
  based_name=$(basename $f .pdf)
  txt_name="${f%.*}.txt"
  if [[ -f "$txt_name" ]]; then
    echo "$txt_name exists."
    continue
  fi
  pdftotext $f
  title_cased_name=$(title_case $based_name)
  echo -e "$title_cased_name\n\n" | cat - $txt_name | sponge $txt_name
done
```

Next, we have to index the actual content. To do that, we'll put our text content into a search engine, like [sonic](https://github.com/valeriansaliou/sonic).

Grab the binary and set it up.

Next, we'll grab a client to pass data to sonic:

Create a Gemfile in a directory:

```rb
source 'https://rubygems.org'
gem 'sonic-ruby'
```

Bundle install the gem:

```sh
$ bundle install
```

Next, create a file called `ingest.rb`. This will ingest your textual data:

Since the client I'm using right now doesn't have throttling, it causes a panic caused by a buffer overflow on the search engine by shoving too much data too quickly. To fix this, I overwrite that method in the file and use it.

```rb
require 'sonic-ruby'

module Sonic
  module Channels
    refine Ingest do
      def push(collection, bucket, object, text, lang = nil)
        puts "processing #{object}"
        text_size = text.size
        text = text.encode('UTF-8', :invalid => :replace, :undef => :replace)
        right = 5000
        left = 0
        loop do
          break if right > text_size


          arr = [collection, bucket, object, quote(text[left...right].gsub('"', ''))]
          arr << "LANG(#{lang})" if lang

          execute('PUSH', *arr)
          right += 5000
          left += 5000
        end
      end
    end
  end
end

using Sonic::Channels

# Connect to the Sonic server on localhost:1491
client = Sonic::Client.new('localhost', 1491, 'SecretPassword')

# Connect to the ingest channel
ingest = client.channel(:ingest)

Dir.glob("$PATH_TO_FILES/**/*.txt") do |f|
  pdf_name = f[0..-3] + 'pdf'
  text = IO.read(f)
  ingest.push('books', 'all', pdf_name, text)
end
```

Run that script with:

```sh
ruby ingest.rb
```

And then lets get searching!
Create this file as `search.rb`:

```rb
require 'sonic-ruby'

if ARGV.length != 1
  puts "Too many names ... or not enough name?"
  exit
else
  name = ARGV[0]
end

# Connect to the Sonic server on localhost:1491
client = Sonic::Client.new('localhost', 1491, 'SecretPassword')

# Connect to the search channel
search = client.channel(:search)

puts "searching for #{name}"

# Search for a matching name and return ID
search.query('books', 'all', name, 100).split(' ').each do |doc|
  puts doc
end
```

And then run a search:

```sh
$ ruby search.rb "Oysters"
searching for Oysters
/books/programming-languages/python/effective-python.pdf
/books/math/probability-theory-the-logic-of-science.pdf
/books/algorithms/programming-pearls.pdf
```

And that's it. How to index your books in 15 minutes or less, guaranteed or your money back.
