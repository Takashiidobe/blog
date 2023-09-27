---
title: "Writing a Small Search Engine"
date: 2023-07-27T07:20:52-04:00
draft: false
---

Today we're going to write a small search engine in ~70 lines of code:

```
$ cloc --quiet src/main.rs

github.com/AlDanial/cloc v 1.90  T=0.00 s (271.8 files/s, 22288.4 lines/s)
-------------------------------------------------------------------------------
Language                     files          blank        comment           code
-------------------------------------------------------------------------------
Rust                             1             12              1             69
-------------------------------------------------------------------------------
```

The implementation leans on using a few dependencies from crates.io, so let's fetch those first.

Initialize a new rust project:

```sh
cargo new tinysearch
```

```sh
cargo add anyhow
cargo add bincode
cargo add glob
cargo add patricia_tree --features=serde
cargo add serde --features=derive
```

With that, your Cargo.toml should have this for its dependencies.

```toml
[dependencies]
anyhow = "1.0.70"
bincode = "1.3.3"
glob = "0.3.1"
patricia_tree = { version = "0.5.7", features = ["serde"] }
serde = { version = "1.0.160", features = ["derive"] }
```

Anyhow is used as `box<dyn Error>`, so it's not really necessary, but it's nice to not have to write.

Bincode is used for serialization and deserialization to disk for data structures. We'll need this to store the search index on disk and fetch it when we do a search.

Glob is for making glob queries, like `src/**/*.rs` to fetch all rust files recursively under the `src` directory.

Patricia tree is a trie data structure, that has the same ADT as a map or set. Since this is a trie, and not a hashmap or btree, if there are redundant prefixes, they are compressed on disk. Since we're serializing and deserializing text, which tends to be somewhat redundant, this potentially saves a lot of memory compared to using a hash-based or normal tree-based structure.

Serde is used to serialize the tree onto disk and deserialize it, for bincode.

## Index Implementation

Given the explanation above, your mental model to populate the index should be something like this:

1. Initialize Trie
2. Fill Trie with some data (how?)
3. Save Trie to disk

And to read from it:

1. Read the file containing Trie to disk
2. Deserialize it back to a Trie
3. Query the trie

The open question is what data we fill the Trie with. Obviously it would be something from our dataset, but if we make a mapping from each word to its document name, then this works, but we can only query one word at a time.

With this index, a query like "ice cream" would only be able to query for either "ice" or "cream".

To keep it simple, we'll choose an indexing strategy referred to as n-grams. N-grams indexes windows of length n. Our previous strategy of indexing every word could be considered a 1-gram. We'll go with 5, since that allows us to query up to 5 words. I queried my search history and found that 5 word queries just about covers my querying needs.

Let's get coding:

in `src/main.rs`, add the imports required:

```rust
use std::{
    collections::{BTreeSet, HashSet},
    fs::{self, File},
    io::{BufRead, BufReader},
};

use patricia_tree::PatriciaMap;

use anyhow::Result;
use glob::glob;
```

Next, let's create the cli flags with the two commands we'll support, `search` and `index`.

```rust
fn main() -> Result<()> {
    use std::env::args;
    match args().len() {
        0 => eprintln!("Please provide a top level command of search or index"),
        _ => {
            let arguments: Vec<_> = args().collect();
            if args().len() > 2 && arguments[1] == "index" {
                let _ = index(&arguments[2]);
            } else if args().len() > 2 && arguments[1] == "search" {
                let _ = search(&arguments[2..]);
            } else {
                eprintln!("Please provide a top level command of search or index");
            }
        }
    }
    Ok(())
}
```

Next, the function definition and matching patterns based on it.

This code matches a regex provided (like "**/*.rs"), and then returns all matching files. We then iterate through the files and process each line.

```rust
fn index(pattern: &str) -> Result<()> {
    let mut mytrie = PatriciaMap::default();

    for entry in glob(pattern)? {
        let path = entry?;
        let path = path.to_string_lossy().to_string();

        let f = File::open(&*path)?;
        let f = BufReader::new(f);

        for line in f.lines() {
            // process each line, the next step
        }
    }
}
```

Next, we want to do something for each line. First, split each line on whitespace to get a list of words. A production worthy search engine would do stemming and remove unnecessary punctuation here, but we won't worry about that. Finally, we'll use the [`windows`](https://doc.rust-lang.org/std/primitive.slice.html#method.windows) function on slices, to return arrays with the length provided (5) across the entire list. This is n-grams in a nutshell.


```rust
let line = line?;
let s: String = line.to_string();
let words: Vec<String> = s.split_whitespace().map(|s| s.to_owned()).collect();
let word_windows: Vec<String> = words.windows(5).map(|w| w.join(" ")).collect();
```

With that, the next thing to do is to put each five gram as a key to the trie, with a value of the path of the document.
If that fivegram already exists, we just add the new path to the list of paths it matches.

```rust
for fivegram in &word_windows {
    if !mytrie.contains_key(fivegram) {
        let mut set = BTreeSet::default();
        set.insert(path.clone());
        mytrie.insert(fivegram, set);
    } else {
        // we know that the trie contains fivegram, so unwrapping is safe.
        let mut set: BTreeSet<String> = mytrie.get(fivegram).unwrap().to_owned();
        set.insert(path.clone());
        mytrie.insert(fivegram, set);
    }
}
```

Finally, we serialize it and write it to a file:

```rust
let encoded = bincode::serialize(&mytrie)?;
fs::write("./data.index", encoded)?;
Ok(())
```

## Searching our Index

Fortunately, searching is easier. We take our list of search words, and then index into the map. Then, we grab the matches, and we append them to all matching paths. At the end, we print them out.

```rust
fn search(search_words: &[String]) -> Result<()> {
    let needle: Vec<u8> = {
        let joined = search_words.join(" ");
        joined.bytes().collect()
    };

    let index_file = File::open("./data.index")?;
    let decoded: PatriciaMap<BTreeSet<String>> = bincode::deserialize_from(index_file)?;

    let matches: Vec<_> = decoded.iter_prefix(&needle).collect();

    let mut paths: HashSet<_> = HashSet::default();
    for (_key, val) in &matches {
        paths.extend(val.iter());
    }

    println!("{:#?}", paths);
    Ok(())
}
```

And with that, we're done. A simple search engine.

## Giving it a test run

I indexed my notes:

```sh
cargo r -q -- index "data/**/*.md"
```

And then searched for mentions of distributed systems:

```sh
cargo r -q -- search distributed system
{
    "data/books/system-design-interview-an-insiders-guide-volume-2/distributed-message-queue.md",
    "data/books/designing-data-intensive-applications/distributed-systems-trouble.md",
}
```

Not so bad for 70 lines of code.
