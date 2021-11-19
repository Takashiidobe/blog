---
title: "Offline e-mail in the terminal"
date: 2021-10-27T09:44:59-05:00
draft: false 
---

I like putting stuff in the terminal. Let's roll back the clock 30 years and go back to terminal e-mail. 

Let's start with installing an e-mail client.

I like [aerc](https://aerc-mail.org/). I also use mac OS, so it can be installed with a simple `brew install aerc`.

## Setting up Aerc

Here's another guide for that: [Text based gmail](https://oren.github.io/articles/text-based-gmail/)

I personally use a gmail, so I had to create a gmail app password to provide to aerc.

On first startup, aerc has a startup wizard that helps you set up your account. Nice! Put in your information and enjoy e-mail in the terminal. 


My `aerc/accounts.conf` looks something like this:

```{.sh .numberLines}
[Personal]
source        = imap://me@gmail.com:password@imap.gmail.com:993
outgoing      = smtp+plain://me@gmail.com:$APP_PASSWORD_HERE@smtp.gmail.com:587
smtp-starttls = yes
from          = Me <me@gmail.com>
copy-to       = Sent
```

As well, I wanted to change up some of the defaults: 

I set my `aerc/aerc.conf` like so: this sets my pager to `bat` instead of `less -R`, and prefers to display the HTML portion of an email first if possible, then falling back to the plain text version. 

To be able to read HTML e-mail, I uncommented the line for text/html, and use the html filter that's provided by aerc. This requires `w3m` and `dante`, so I brew installed both:

```{.sh .numberLines}
brew install w3m
brew install dante
```

```{.sh .numberLines}
[viewer]
pager=/usr/local/bin/bat
alternatives=text/html,text/plain

[filters]
subject,~^\[PATCH=awk -f @SHAREDIR@/filters/hldiff
text/html=bash /usr/local/share/aerc/filters/html
text/*=awk -f /usr/local/share/aerc/filters/plaintext
```

Great! Now we're all set up with aerc.

## Offline Support

This is great and all, but try to run `aerc` without internet connection. It hangs. That's not acceptable! Let's fix that. 

Drew DeVault, the original author of `aerc` published a guide on making `aerc` work offline <https://drewdevault.com/2021/05/17/aerc-with-mbsync-postfix.html>. We'll follow this guide a bit, but I use gmail instead of `migadu`, and ended up using `msmtp` instead of `postfix`, so there'll be a few changes.

### Mbsync for reading e-mail offline 

Let's start off installing `mbsync`. On Mac OS it is listed as its previous name, `isync`. So run `brew install isync` to install it.

We'll then set it up -- the config file is at `~/.mbsyncrc`, so create that and fill it with this: 

```{.sh .numberLines}
IMAPStore gmail-remote
Host imap.gmail.com
AuthMechs LOGIN
User you@gmail.com
Pass $APP_PASSWORD_HERE 
SSLType IMAPS

MaildirStore gmail-local
Path ~/mail/gmail/
Inbox ~/mail/gmail/INBOX
Subfolders Verbatim

Channel gmail
Far :gmail-remote:
Near :gmail-local:
Expunge Both
Patterns * !"[Gmail]/All Mail" !"[Gmail]/Important" !"[Gmail]/Starred" !"[Gmail]/Bin"
SyncState *
```

If you don't already have a `~/mail/gmail/INBOX` folder, create it with `mkdir -p ~/mail/gmail/INBOX`.

Now, if you run `mbsync gmail`, all of your e-mail will be synced to your `~/mail/gmail` folder.

Now, we just need aerc to pull locally instead of from gmails servers.

Go back to `aerc/accounts.conf`, and edit the source under the [Personal] tag to point to `maildir://~/mail`. This will let aerc read your e-mail locally instead of from gmail's servers.

As well, set the default to `gmail/INBOX` to land in your inbox folder on start.

```{.sh .numberLines} 
[Personal]
source        = maildir://~/mail
outgoing      = smtp+plain://me@gmail.com:$APP_PASSWORD_HERE@smtp.gmail.com:587
default       = gmail/INBOX
smtp-starttls = yes
from          = Me <me@gmail.com>
copy-to       = Sent
```

Turn off your internet and run `aerc`. Now you can read your e-mail offline! We'll want to always keep our mailbox in sync, so we'll want to run `mbsync` frequently to keep our mailbox in sync.

First, we'll need a program called `chronic`, which is provided in `moreutils`. Download it with `brew install moreutils`.

Run `crontab -e` to edit your local crontab, and put this in it.

This will have cron execute `mbsync gmail` every minute, keeping your mailbox in sync with google's servers.

```{.sh .numberLines} 
MAILTO=""
PATH=YOUR_PATH_HERE
* * * * * chronic mbsync gmail
```

### Sending E-mail offline 

If you try to send e-mail while offline on aerc currently, the e-mail will never send. What we'd like is some queue where the e-mail is sent immediately if we're online, otherwise, to save that message in a queue, and send out all messages immediately as we regain connectivity.

We'll use `msmtp` for that. 

Install it with `brew install msmtp`.

msmtp's config file is called `~/.msmtprc`. Fill that file with this:

```{.sh .numberLines} 
defaults
tls on

account gmail
auth on
host smtp.gmail.com
port 587
user me 
from me@gmail.com
password APP_PASSWORD_HERE

account default: gmail
```

Now we can send e-mail from the command line. This isn't super useful yet, since aerc has this functionality already. Next, we need to implement the queueing capability we discussed. You'll want to download two bash scripts that do this for us: `msmtpq` and `msmtp-queue`. These can be found here: <https://github.com/tpn/msmtp/tree/master/scripts/msmtpq>. Make them executable and place them somewhere on your path (I chose `/usr/local/bin`). This implements the queueing that be discussed. 

Finally, we'll have to hook up `aerc` to use this capability in `accounts.conf`.

```{.sh .numberLines} 
[Personal]
source        = maildir://~/mail
outgoing      = /usr/local/bin/msmtpq
default       = gmail/INBOX
smtp-starttls = yes
from          = Me <me@gmail.com>
copy-to       = Sent
```

Finally, we'll want to be able to execute the queueing functionality of `msmtpq` every minute as well. Edit your crontab to look like this: 

```{.sh .numberLines} 
MAILTO=""
PATH=YOUR_PATH_HERE
* * * * * chronic mbsync gmail
* * * * * chronic msmtp-queue -r
```

And with that, we're done! We can now read e-mail offline, which syncs every minute when online, and send e-mail offline, which will get queued, and sent as soon as we're back online again. 
