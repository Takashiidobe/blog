---
title: "Unix Environment Variables"
date: 2021-05-24T18:58:40-04:00
draft: false
---

Let's talk about some popular unix environment variables:

- `$USER` - The current user
- `$PAGER` - the program that accepts page by page input. `less` and `more` are good examples.
- `$VISUAL` - A full screen editor (like `vi`, `emacs`, and `nano`).
- `$EDITOR` - A line by line editor (`ed` or `ex` work).
- `$PWD` - the current working directory
- `$HOME` - the home directory
- `$LANG` - the language you use, with an optional encoding.
- `$MANPATH` - the list of directories to search for manual pages.
- `$MAIL` - where mail goes
- `$SHELL` - path to shell binary you use (e.g. `/bin/bash`, `/bin/ksh`, `/bin/sh`, `/bin/zsh`)

The most important one is probably `$PATH`, which is where the OS looks for binaries.
It goes from the beginning to the end, executing the first binary it finds.

Let's say my `$PATH` is like this:

```{.bash .numberLines}
/usr/local/bin:/usr/bin
```

Which instructs the OS to look into `/usr/local/bin` to find a valid binary. Then `/usr/bin`.

The `/bin` directory contains binaries for sysadmins and users, but are required when there's no filesystem in use.

The `/usr/bin` and was meant to contain executable programs that were part of the OS

and `/usr/local/bin` is for software that the user installs.

There directories where superuser binaries should be located which follow the same scheme:

- `/sbin`
- `/usr/sbin`
- `/usr/local/sbin`

As well, `/usr/share/bin` is for binaries used for web servers and clients.

If you find that a command doesn't work, double-check to make sure that your `$PATH` is set up properly to find the correct binary.
