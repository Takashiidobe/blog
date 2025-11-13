---
title: "Writing a Container"
date: 2025-11-12T15:55:26-05:00
draft: false
---

I use containers on the job daily, but to be honest, don't have much
idea other than they're vaguely `chroot()` + `cgroupsv2` + `seccomp`.
So, to rectify that, let's build our own containers.

## Dependencies

First off, some dependencies. Since we want to run binaries inside of
our chroot, and our chroot is going to be far away from root, we have
two options:

1. compile with vanilla `gcc` and then copy our shared libraries to our
   chroot.
2. Statically compile our dependencies.

I went with 2. But that leaves the compiler itself. Luckily, there's
a project called [crosstool-NG](https://crosstool-ng.github.io/) that
allows you to generate cross-compilers pretty easily. My target is
`x86_64-unknown-linux-gnu`, so I just needed a build of
`x86_64-unknown-linux-musl`. After adding the compiler to your `$PATH`,
you're also ready to statically compile some code.

## A Shell

To get interactivity in our `chroot`, we'll need a shell. I chose `dash`
because it's easier to compile. Clone it, and let's compile it with our
cross compiler.

```sh
git clone https://git.kernel.org/pub/scm/utils/dash/dash.git/ --depth=1
```

In bash or zsh, set your compiler, and build. Dash will be built in
`src/dash`. Copy it for later.

```sh
cd dash
export PATH="$HOME/x-tools/x86_64-unknown-linux-musl/bin:$PATH"
export CC="x86_64-unknown-linux-musl-gcc"
export LD="x86_64-unknown-linux-musl-ld"
export CFLAGS="-Os"
export LDFLAGS="--static"
make
```

## A Userspace

For a userspace, I decided to use toybox. 

Same drill, compile it statically.

```sh
git clone https://github.com/landley/toybox.git --depth=1
```

```sh
cd toybox
export PATH="$HOME/x-tools/x86_64-unknown-linux-musl/bin:$PATH"
export CROSS_COMPILE=x86_64-unknown-linux-musl- 
export LDFLAGS="--static"
make distclean
make defconfig
make toybox CROSS_COMPILE=$CROSS_COMPILE
make
```

`toybox` will be in the root directory. Keep it for later.

## An operating system?

Now we'll need the directory structure of an operating system. Luckily,
toybox also has us covered. There's a script called `mkroot/mkroot.sh`
which when run, will create our root filesystem.

```sh
$ mkroot/mkroot.sh
```

Run it, and copy the `root` dir to where you want your OS to be. Now,
copy over `dash` and `toybox` into `root/bin`, and you have a userspace
and a shell. What more could you want?

## Chrooting to our OS

If you `cd` into `root` and then run `bin/toybox ls`, you actually have
an OS inside your OS. Of course, it's pretty useless since you can `cd`
out. This is basically what `chroot` does for us -- it puts the root dir
wherever you specify, and that's it.

With that out of the way, let's write a program that uses `chroot`.

```c
#define _GNU_SOURCE
#include <errno.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/*
 * Stage 0: Minimal chroot launcher.
 *
 * This version demonstrates the tiniest "container": it simply chroots into a
 * user-specified directory and execs a command. You must run it as root and
 * it is trivial to escape by pointing -r at "/" or any other host path
   and escaping.
 */

static void die(const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  vfprintf(stderr, fmt, ap);
  va_end(ap);
  if (!*fmt || fmt[strlen(fmt) - 1] != '\n')
    fputc('\n', stderr);
  exit(EXIT_FAILURE);
}

static void usage(const char *prog) {
  fprintf(stderr, "Usage: %s -r <rootfs> -- <cmd> [args...]\n", prog);
  exit(2);
}

int main(int argc, char **argv) {
  const char *root = NULL;

  /* Parse: expect -r <root> followed by -- and the command */
  for (int i = 1; i < argc; i++) {
    if (!strcmp(argv[i], "-r") && i + 1 < argc) {
      root = argv[++i];
    } else if (!strcmp(argv[i], "--")) {
      argv += i + 1;
      argc -= i + 1;
      break;
    } else if (argv[i][0] == '-') {
      usage(argv[0]);
    } else {
      argv += i;
      argc -= i;
      break;
    }
  }
  if (!root || argc < 1)
    usage(argv[0]);

  if (chroot(root) == -1)
    die("chroot(%s): %s", root, strerror(errno));
  if (chdir("/") == -1)
    die("chdir(/): %s", strerror(errno));

  execvp(argv[0], argv);
  die("execvp('%s') failed: %s", argv[0], strerror(errno));
}
```

Compile this and we have to run it as root. Point it to our little
filesystem and we can drop into the shell.

```sh
gcc container.c -o container -lseccomp
```

Note that we have to use `sudo` here otherwise we can't get into the
`chroot`.

```sh
sudo ./container -r ./root -- /bin/dash
```

We're actually not able to do too much to just leave:

```sh
# pwd
/
# cd /root/takashi
/bin/dash: 5: cd: can't cd to /root/takashi
```

But remember, we're root. We can escape using proc.

```sh
# toybox mkdir /proc
# toybox mount -t proc proc /proc
# toybox chroot /proc/1/root /bin/sh
$ whoami
root
```

And you're in a root shell as root. Freedom, so very easily.

## Some more security

We'll want to prevent running as root. And also escaping so easily. This
time around, we'll make the container runnable without root, mount
`/proc` privately, clean up the environment, and change our user to
nobody. We can still run any syscall we want though.

```c
static void make_private_mounts(void) {
  if (mount(NULL, "/", NULL, MS_REC | MS_PRIVATE, NULL) == -1)
    die("mount(/, MS_PRIVATE): %s", strerror(errno));
}

static void bind_mount_self(const char *path) {
  if (mount(path, path, NULL, MS_BIND | MS_REC, NULL) == -1)
    die("bind-mount %s: %s", path, strerror(errno));
}

static void close_all_fds_except012(void) {
  int dir = open("/proc/self/fd", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
  if (dir < 0) {
    for (int fd = 3; fd < 1024; ++fd)
      close(fd);
    return;
  }
  char name[PATH_MAX];
  for (;;) {
    ssize_t n = syscall(SYS_getdents64, dir, name, sizeof(name));
    if (n <= 0)
      break;
    for (ssize_t i = 0; i < n;) {
      struct linux_dirent64 {
        ino64_t d_ino;
        off64_t d_off;
        unsigned short d_reclen;
        unsigned char d_type;
        char d_name[];
      };
      struct linux_dirent64 *d = (struct linux_dirent64 *)(name + i);
      i += d->d_reclen;
      if (!strcmp(d->d_name, ".") || !strcmp(d->d_name, ".."))
        continue;
      int fd = atoi(d->d_name);
      if (fd > 2 && fd != dir)
        close(fd);
    }
  }
  close(dir);
}

static void drop_privileges(uid_t uid, gid_t gid) {
  if (setgroups(0, NULL) == -1 && errno != EPERM)
    die("setgroups: %s", strerror(errno));
  if (setgid(gid) == -1)
    die("setgid: %s", strerror(errno));
  if (setuid(uid) == -1)
    die("setuid: %s", strerror(errno));
}

static void write_file_fmt(const char *path, const char *fmt, ...) {
  int fd = open(path, O_WRONLY);
  if (fd == -1)
    die("open(%s): %s", path, strerror(errno));

  char buf[256];
  va_list ap;
  va_start(ap, fmt);
  int len = vsnprintf(buf, sizeof(buf), fmt, ap);
  va_end(ap);
  if (len < 0 || (size_t)len >= sizeof(buf))
    die("formatting %s failed", path);
  if (write(fd, buf, len) != len)
    die("write(%s): %s", path, strerror(errno));
  close(fd);
}

static void setup_user_namespace(uid_t host_uid, gid_t host_gid) {
  if (unshare(CLONE_NEWUSER) == -1)
    die("unshare(CLONE_NEWUSER): %s", strerror(errno));

  if (access("/proc/self/setgroups", F_OK) == 0)
    write_file_fmt("/proc/self/setgroups", "deny\n");

  write_file_fmt("/proc/self/uid_map", "0 %u 1\n", host_uid);
  write_file_fmt("/proc/self/gid_map", "0 %u 1\n", host_gid);
}
```

And the changes to main:

```c
int main(int argc, char **argv) {
  const char *root = NULL;
  uid_t host_uid = geteuid();
  gid_t host_gid = getegid();
  bool rootless = (host_uid != 0);
  uid_t uid = rootless ? 0 : 65534;
  gid_t gid = rootless ? 0 : 65534;

  for (int i = 1; i < argc; i++) {
    if (!strcmp(argv[i], "-r") && i + 1 < argc) {
      root = argv[++i];
    } else if (!strcmp(argv[i], "-u") && i + 1 < argc) {
      uid = (uid_t)strtoul(argv[++i], NULL, 10);
    } else if (!strcmp(argv[i], "-g") && i + 1 < argc) {
      gid = (gid_t)strtoul(argv[++i], NULL, 10);
    } else if (!strcmp(argv[i], "--")) {
      argv += i + 1;
      argc -= i + 1;
      break;
    } else if (argv[i][0] == '-') {
      usage(argv[0]);
    } else {
      argv += i;
      argc -= i;
      break;
    }
  }
  if (!root || argc < 1)
    usage(argv[0]);

  if (rootless && (uid != 0 || gid != 0))
    die("non-root users must use -u/-g 0 in this stage");

  setup_user_namespace(host_uid, host_gid);

  if (unshare(CLONE_NEWNS) == -1)
    die("unshare(CLONE_NEWNS): %s", strerror(errno));
  make_private_mounts();

  bind_mount_self(root);
  if (chroot(root) == -1)
    die("chroot(%s): %s", root, strerror(errno));
  if (chdir("/") == -1)
    die("chdir(/): %s", strerror(errno));

  mkdir("/proc", 0555);
  mount("proc", "/proc", "proc", MS_NOSUID | MS_NODEV | MS_NOEXEC, NULL);

  clearenv();
  close_all_fds_except012();
  drop_privileges(uid, gid);

  execvp(argv[0], argv);
  die("execvp('%s') failed: %s", argv[0], strerror(errno));
}
```

Now, do we have an escape? If you do it right, no. However, there's a
convoluted way of getting out.

If we know there's a process that has access to the root file system,
mounting, etc, we "hack" it in a bit of an odd way with `ptrace`.
`Ptrace` allows us to "observe" and "control" the execution of other
processes. With this, we can have it be a confused deputy and mount our
file system and therefore get a way to chroot out. Compile this program
and point it to a victim pid on the host that can mount for us:

```c
int main(int argc, char **argv) {
  pid_t pid = atoi(argv[1]);
  struct user_regs_struct regs;
  
  ptrace(PTRACE_ATTACH, pid, 0, 0);
  waitpid(pid, NULL, 0);
  ptrace(PTRACE_GETREGS, pid, 0, &regs);
  regs.orig_rax = SYS_mount;
  regs.rdi = (unsigned long)"/host";
  regs.rsi = (unsigned long)"/mnt";
  regs.rdx = MS_BIND;
  regs.r10 = 0;
  ptrace(PTRACE_SETREGS, pid, 0, &regs);
  ptrace(PTRACE_SYSCALL, pid, 0, 0);
  waitpid(pid, NULL, 0);
  ptrace(PTRACE_DETACH, pid, 0, 0);
  return 0;
}
```

And we are out:

```sh
$ toybox chroot /mnt /bin/sh
```

## Even More Security

So we've learned that `ptrace` is evil in this case. What we need is a
way to only allow certain syscalls. Thankfully, `seccomp` will do that for
us -- if you try to run a syscall, it will get killed.

Let's add some extra headers and some helpers:

```c
#include <seccomp.h>
#include <signal.h>
#include <sys/prctl.h>
#include <sys/resource.h>

static void setup_user_namespace(uid_t host_uid, gid_t host_gid,
                                 uid_t target_uid, gid_t target_gid) {
  char map_buf[256];
  int len = 0;

  if (host_uid == 0) {
    len = snprintf(map_buf, sizeof(map_buf), "0 %u 1\n", host_uid);
    if (target_uid != 0)
      len += snprintf(map_buf + len, sizeof(map_buf) - len, "%u %u 1\n",
                      target_uid, target_uid);
  } else {
    if (target_uid != 0)
      die("non-root users must run with -u 0 (got %u)", target_uid);
    len = snprintf(map_buf, sizeof(map_buf), "0 %u 1\n", host_uid);
  }
  if (len < 0 || (size_t)len >= sizeof(map_buf))
    die("uid_map formatting overflow");
  write_file_fmt("/proc/self/uid_map", "%s", map_buf);

  len = 0;
  if (host_uid == 0) {
    len = snprintf(map_buf, sizeof(map_buf), "0 %u 1\n", host_gid);
    if (target_gid != 0)
      len += snprintf(map_buf + len, sizeof(map_buf) - len, "%u %u 1\n",
                      target_gid, target_gid);
  } else {
    if (target_gid != 0)
      die("non-root users must run with -g 0 (got %u)", target_gid);
    len = snprintf(map_buf, sizeof(map_buf), "0 %u 1\n", host_gid);
  }
  if (len < 0 || (size_t)len >= sizeof(map_buf))
    die("gid_map formatting overflow");
  write_file_fmt("/proc/self/gid_map", "%s", map_buf);
}

static void sigsys_handler(int _nr, siginfo_t *info, void *_uctx) {
  (void)_nr;
  (void)_uctx;
  if (!info) {
    fprintf(stderr, "blocked syscall (no info)\n");
  } else {
    fprintf(stderr, "blocked syscall %d (arch %#x, addr %p)\n",
            info->si_syscall, info->si_arch, info->si_call_addr);
  }
  _exit(1);
}

static void install_sigsys_logger(void) {
  struct sigaction sa;
  memset(&sa, 0, sizeof(sa));
  sa.sa_sigaction = sigsys_handler;
  sa.sa_flags = SA_SIGINFO | SA_RESETHAND;
  if (sigaction(SIGSYS, &sa, NULL) == -1)
    die("sigaction(SIGSYS): %s", strerror(errno));
}

static void install_seccomp_allowlist() {
  if (prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) == -1)
    die("prctl(NO_NEW_PRIVS): %s", strerror(errno));

  scmp_filter_ctx ctx = seccomp_init(SCMP_ACT_TRAP);
  if (!ctx)
    die("seccomp_init failed");

#define ALLOW(syscall)                                                         \
  do {                                                                         \
    if (seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(syscall), 0))           \
      die("allow " #syscall " failed");                                        \
  } while (0)
#define ALLOW_ARG(syscall, idx, cmp, val)                                      \
  do {                                                                         \
    if (seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(syscall), 1,            \
                         SCMP_CMP(idx, cmp, val)))                             \
      die("allow " #syscall " arg failed");                                    \
  } while (0)

  ALLOW(rt_sigaction);
  ALLOW(rt_sigprocmask);
  ALLOW(umask);
  ALLOW(rt_sigreturn);
  ALLOW(exit);
  ALLOW(exit_group);
  ALLOW(getpid);
  ALLOW(getppid);
  ALLOW(gettid);
  ALLOW(futex);
  ALLOW(clone);
  ALLOW(set_tid_address);
  ALLOW(set_robust_list);

  ALLOW(clock_gettime);
  ALLOW(clock_nanosleep);
  ALLOW(nanosleep);
  ALLOW(getrandom);

  ALLOW(brk);
  ALLOW(mmap);
  ALLOW(munmap);
  ALLOW(mremap);
  ALLOW(mprotect);

  ALLOW(arch_prctl);
  ALLOW(getuid);
  ALLOW(geteuid);
  ALLOW(getgid);
  ALLOW(getegid);
  ALLOW(prlimit64);
  ALLOW(prctl);
  ALLOW(madvise);
  ALLOW(access);
  ALLOW(faccessat2);
  ALLOW(pread64);
  ALLOW(rseq);
  ALLOW(fadvise64);

  ALLOW(read);
  ALLOW(write);
  ALLOW(writev);
  ALLOW(close);
  ALLOW(lseek);
  ALLOW(getdents64);
  ALLOW(ioctl);
  ALLOW(statx);
  ALLOW(fstat);
  ALLOW(fstatfs);
  ALLOW(newfstatat);
  ALLOW(fcntl);
  ALLOW(dup);
  ALLOW(dup2);
  ALLOW(dup3);
  ALLOW(pipe);
  ALLOW(pipe2);
  ALLOW(readlink);
  ALLOW(readlinkat);
  ALLOW(uname);
  ALLOW(open);
  ALLOW(openat);

  ALLOW(execve);
  ALLOW(execveat);

  ALLOW(socket);
  ALLOW(connect);
  ALLOW(bind);
  ALLOW(listen);
  ALLOW(accept);
  ALLOW(accept4);
  ALLOW(getsockopt);
  ALLOW(setsockopt);
  ALLOW(getsockname);
  ALLOW(getpeername);
  ALLOW(sendto);
  ALLOW(recvfrom);
  ALLOW(sendmsg);
  ALLOW(recvmsg);
  ALLOW(shutdown);

  ALLOW(clone3);
  ALLOW(eventfd2);
  ALLOW(poll);
  ALLOW(statfs);
  ALLOW(getcwd);
  ALLOW(getpgid);
  ALLOW(setpgid);
  ALLOW(stat);
  ALLOW(vfork);
  ALLOW(wait4);

  seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(chroot), 0);
  seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(pivot_root), 0);
  seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(mount), 0);
  seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(umount2), 0);
  seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(open_by_handle_at), 0);
  seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(name_to_handle_at), 0);
  seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(bpf), 0);
  seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(kexec_load), 0);
  seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(kexec_file_load), 0);
  seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(ptrace), 0);

  if (seccomp_load(ctx) != 0) {
    seccomp_release(ctx);
    die("seccomp_load failed");
  }
  seccomp_release(ctx);
#undef ALLOW
#undef ALLOW_ARG
```

And fix up main.

```c
int main(int argc, char **argv) {
  const char *root = NULL;
  uid_t host_uid = geteuid();
  gid_t host_gid = getegid();
  bool rootless = (host_uid != 0);
  uid_t uid = rootless ? 0 : 65534;
  gid_t gid = rootless ? 0 : 65534;

  for (int i = 1; i < argc; i++) {
    if (!strcmp(argv[i], "-r") && i + 1 < argc) {
      root = argv[++i];
    } else if (!strcmp(argv[i], "-u") && i + 1 < argc) {
      uid = (uid_t)strtoul(argv[++i], NULL, 10);
    } else if (!strcmp(argv[i], "-g") && i + 1 < argc) {
      gid = (gid_t)strtoul(argv[++i], NULL, 10);
    } else if (!strcmp(argv[i], "--")) {
      argv += i + 1;
      argc -= i + 1;
      break;
    } else if (argv[i][0] == '-') {
      usage(argv[0]);
    } else {
      argv += i;
      argc -= i;
      break;
    }
  }
  if (!root || argc < 1)
    usage("container");

  if (rootless && (uid != 0 || gid != 0))
    die("non-root users can only use -u/-g 0 (try running as root for other "
        "ids)");

  setup_user_namespace(host_uid, host_gid, uid, gid);

  if (unshare(CLONE_NEWNS) == -1)
    die("unshare(CLONE_NEWNS): %s", strerror(errno));
  make_private_mounts();

  bind_mount_self(root);
  if (chroot(root) == -1)
    die("chroot(%s): %s", root, strerror(errno));
  if (chdir("/") == -1)
    die("chdir(/): %s", strerror(errno));

  mkdir("/proc", 0555);
  if (mount("proc", "/proc", "proc", MS_NOSUID | MS_NODEV | MS_NOEXEC, NULL) ==
      -1) {
  }

  clearenv();
  close_all_fds_except_std();

  drop_privileges(uid, gid);

  install_sigsys_logger();
  install_seccomp_allowlist();

  execvp(argv[0], argv);
  die("execvp('%s') failed: %s", argv[0], strerror(errno));
}
```

Now with this, we can't try any `ptrace` tricks, since we've explicitly
disallowed it. As well, we've added a helper that lets us strace a task
to see which syscall killed our task (good for debugging).

I've allowed enough syscalls to allow for one last party trick -- a way
to call the network (on your own computer).

I spun up an http server serving the `container.c` file at 
`127.0.0.1:8080/container.c`:

And look, there's the code.

```sh
./container_3 -r root/ -- /bin/dash
$ toybox wget http://127.0.0.1:8080/container.c -O -
# the code we've been writing today.
```

If you're a little too overzealous with the system calls, there's
probably an escape out, but we can cover the most egregious ones with
the seccomp denylist. You can configure the list how you like and you
can get a passable toy container and play around with it.
