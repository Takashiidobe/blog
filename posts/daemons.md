---
title: "Daemons"
date: 2025-11-13T09:42:06-05:00
draft: false
---

Daemons are processes that run in the background without interaction. An
example would be `sshd`, which accepts ssh connections in the
background.

Nowadays, on linux, it's recommended to use `systemd` to manage your
daemons. `sshd` and other services are registered through `systemd`.
We're going to go old school in this post for fun.

A daemon shouldn't be reachable from the outside world, and it should do
a task on some activity or change. You can run one or as many of them as
you want to -- maybe you want just one like a singleton, or many
splitting up a task, or you can emulate a single writer many readers
pattern. 

Regardless, here's the checklist of "how to daemon"

1. Fork + exit from the parent.
2. `setsid()` after the first fork to get a new progress group id.
3. disable `SIGHUP` to prevent the terminal from killing the daemon.
4. Fork again to make sure the daemon process cannot get a terminal.
5. `umask(027)` to set permissions for files it owns
6. `chdir()` to the directory you want
7. Close all FDs that aren't 0/1/2, and redirect 0/1/2 to log files.
8. Get the `pidfile`, write your pid, keep the file open while alive.
9. Install signal handling, `SIGTERM`, `SIGINT` for shutdown, `SIGHUP`
   for reloading.
10. Open any files required for the task.
11. Do the task.
12. Install code on exit, to close resources used + unlink the pidfile.

That's a lot of work. Luckily, the `bsd` folks have us (the linux folks)
covered. They have `libdaemon`, which has a set of helpers to write
daemons. If you choose a higher level language like Rust or Python,
setting up a daemon is 15 lines of code.

In C, the setup code is closer to 40 lines, but it's not that bad
regardless with `libdaemon`  -- it sets up steps 1 to 7 for us.
That leaves just a few steps. We set the path for the pidfile, and
register it with `daemon_pid_file_proc` for it to be set up in the
`daemon_pid_file_create` call later, returning if we couldn't create it.

Next, there's signal handlers installed for `SIGTERM` and `SIGINT`, and
then we do our main loop.

Finally, we'll do our work, which in this case, reads the request_path,
checks how many bytes it has, and then every 5 seconds, logs that to
another file.

Pretty simple, but does the trick in showcasing how a daemon works.

First, we have our includes.

```c
#include <errno.h>
#include <fcntl.h>
#include <libdaemon/daemon.h>
#include <libdaemon/dpid.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
```

Next, our actual work, which will print to the fd we provide.

```c
static void log_file_size(const char *request_path, int result_fd) {
  struct stat st;
  if (stat(request_path, &st) < 0) {
    if (errno == ENOENT)
      dprintf(result_fd, "# %s missing\n", request_path);
    else
      dprintf(result_fd, "# error reading %s: %s\n", request_path,
              strerror(errno));
    return;
  }
  dprintf(result_fd, "# %s has %ld bytes\n", request_path, st.st_size);
}
```

Next, setting up the variables we need for `libdaemon`.

```c
static volatile sig_atomic_t stop_flag = 0;
static void on_stop(int _sig) { stop_flag = 1; }

static const char *pidfile_path = "/tmp/byte_count_daemon.pid";
static const char *request_path = "/tmp/byte_count_requests.txt";
static const char *result_path = "/tmp/byte_count_results.txt";

static const char *pidfile_proc(void) { return pidfile_path; }
```

And then the main function:

1. You can pass it a `-f` flag as the first argument, if you want to
   run in the foreground for testing.
2. Next, the daemon identifier comes from the name of the binary, and
   then the pidfile path is set afterwards.
3. The daemon call is made only if it's not foregrounded -- so we can
   kill the process.
4. Signal handlers are registered.
5. Pidfile is created -- if it can't be exclusively owned, return here.
6. Open up an fd we need exclusively to write our results to. If we
   can't, we return.
7. The main loop, along with sleeping for 5 seconds between tasks.
8. Stopping and cleaning up.

```c
int main(int argc, char *argv[]) {
  // 1.
  int foreground = (argc > 1 && strcmp(argv[1], "-f") == 0);

  // 2.
  daemon_pid_file_ident = daemon_ident_from_argv0(argv[0]);
  daemon_pid_file_proc = pidfile_proc;

  // 3.
  if (!foreground) {
    if (daemon(0, 0) < 0)
      return 1;
  }

  // 4.
  struct sigaction sa = {0};
  sa.sa_handler = on_stop;
  sigaction(SIGINT, &sa, NULL);
  sigaction(SIGTERM, &sa, NULL);

  // 5.
  if (daemon_pid_file_create() < 0)
    return 1;

  // 6.
  int results_fd = open(result_path, O_WRONLY | O_CREAT | O_APPEND, 0644);
  if (results_fd < 0)
    return 1;

  // 7.
  dprintf(results_fd, "# byte count request daemon started pid=%d\n", getpid());
  while (!stop_flag) {
    log_file_size(request_path, results_fd);
    nanosleep(&(struct timespec){5, 0}, NULL); 
  }

  // 8.
  dprintf(results_fd, "# stopping\n");
  daemon_pid_file_remove();
  close(results_fd);
  return 0;
}
```

Compile the daemon with `cc daemon.c -o daemon -ldaemon`, and run it in
the foreground with `daemon -f`.

Once you start the daemon, you can write and save into
`/tmp/byte_count_requests.txt` and then `tail -f
/tmp/byte_count_results.txt` to see what the daemon is doing.

```txt
# byte count request daemon started pid=438577
# /tmp/byte_count_requests.txt missing
# /tmp/byte_count_requests.txt missing
# /tmp/byte_count_requests.txt has 11 bytes
# /tmp/byte_count_requests.txt has 25 bytes
# /tmp/byte_count_requests.txt has 25 bytes
# /tmp/byte_count_requests.txt has 25 bytes
# /tmp/byte_count_requests.txt has 25 bytes
```

A crash course on daemons in a handful of lines!
