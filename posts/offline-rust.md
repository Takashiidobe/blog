---
title: "Offline Rust"
date: 2023-05-23T18:29:34-04:00
draft: false
---

Rust, and its respective package manager, Cargo, easily allow for programming on the go. You can use `sccache` to cache dependencies you've already downloaded, so if you've already downloaded them, there's no need to redownload them for any other project you use the same dependency for. Sadly, that stops short when you want to download a new dependency you've never downloaded before. If you're offline and don't have that exact dependency cached, you're SOL. But we can do better, can't we?

You probably already know that `crates.io` is a thin layer over git. So, you can grep all the crates on it, download their source code, and host your own local repository that acts as a stand-in for crates.io. Luckily (if you have ~150GB to spare), there's already a project that has done that for us: `panamax`. After you install it with `cargo (b)install panamax`, and initialize some directory. I initialized one at `~/crates` with `panamax init ~/crates`.

You'll want to set your config up: I didn't want to clone any toolchains since I didn't need them, so I only cloned down the crates: I edited my `mirror.toml` inside the initialized repository to be the following:

```toml
[mirror]
retries = 5
[rustup]
sync = false
[crates]
sync = true
download_threads = 64
source = "https://crates.io/api/v1/crates"
source_index = "https://github.com/rust-lang/crates.io-index"
base_url = "http://localhost:27428/crates"
```

And then I ran `panamax sync ~/crates` and waited for a day for the internet to download all the crates.

Once that's done, we have all the crates we need. Add these lines to your cargo config (normally at `~/.cargo/config.toml)` to use the new repository:

```toml
[source.panamax-sparse]
registry = "sparse+http://localhost:27428/index/"

[source.crates-io]
replace-with = "panamax-sparse"
```

Start up the server with `panamax serve ~/crates --port=27428` and you're ready to code offline in rust.

For maintenance, I sync crates with `panamax sync ~/crates` once a week with `systemd` and that works for me.
