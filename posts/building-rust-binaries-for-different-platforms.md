---
title: "Building Rust binaries for different platforms"
date: 2021-11-03T09:24:46-05:00
draft: false 
---

Rust has great support for cross compilation, with `cross`, you can install the required c toolchain + linker and cross compile your rust code to a binary that runs on your targeted platform. Sweet!

If you'd like to look at the code and results, it's in this repo here: <https://github.com/Takashiidobe/rust-build-binary-github-actions>

Rust library writers use this feature to build and test for other platforms than their own: [hyperfine](https://github.com/sharkdp/hyperfine/releases/tag/v1.12.0) for example builds for 11 different platforms.

The [rustc book](https://doc.rust-lang.org/stable/rustc/platform-support.html) has a page on targets and tiers of support. Tier 1 supports 8 targets:

| Tier 1                    |
| ------------------------- |
| aarch64-unknown-linux-gnu |
| i686-pc-windows-gnu       |
| i686-unknown-linux-gnu    |
| i686-pc-windows-msvc      |
| x86_64-apple-darwin       |
| x86_64-pc-windows-gnu     |
| x86_64-pc-windows-msvc    |
| x86_64-unknown-linux-gnu  |

Tier 2 with Host tools supports 21 targets.

| Tier 2                          |
| ------------------------------- |
| aarch64-apple-darwin            |
| aarch64-pc-windows-msvc         |
| aarch64-unknown-linux-musl      |
| arm-unknown-linux-gnueabi       |
| arm-unknown-linux-gnueabihf     |
| armv7-unknown-linux-gnueabihf   |
| mips-unknown-linux-gnu          |
| mips64-unknown-linux-gnuabi64   |
| mips64el-unknown-linux-gnuabi64 |
| mipsel-unknown-linux-gnuabi     |
| powerpc-unknown-linux-gnu       |
| powerpc64-unknown-linux-gnu     |
| powerpc64le-unknown-linux-gnu   |
| riscv64gc-unknown-linux-gnu     |
| s390x-unknown-linux-gnu         |
| x86_64-unknown-freebsd          |
| x86_64-unknown-illumos          |
| arm-unknown-linux-musleabihf    |
| i686-unknown-linux-musl         |
| x86_64-unknown-linux-musl       |
| x86_64-unknown-netbsd           |

Let's try to build a binary for all 29 targets.

## A Note on Targets

The Rust RFC for Target support: <https://rust-lang.github.io/rfcs/0131-target-specification.html>

A target is defined in three or four parts:

`$architecture-$vendor-$os-$environment`

The environment is optional, so some targets have three parts and some have four.

Let's take `x86_64-apple-darwin` for example.

- `x86_64` is the architecture
- `apple` is the vendor
- `darwin` is the os

You'll notice here that there is no `$environment`. This target assumes the environment, which is most likely to be `gnu`.

Let's take one with four parts: `i686-pc-windows-msvc`.

- `i686` is the architecture
- `pc` is the vendor
- `windows` is the os
- `msvc` is the environment

In this target, the environment is specified as `msvc`, the microsoft C compiler. This is the most popular compiler for windows, but it need not be: if you look in the same tier 1 table, there's this target: `i686-pc-windows-gnu`.

The only thing that's changed is the environment is now `gnu`. Windows can use `gcc` instead of `msvc`, so building for this target uses the `gcc` instead of `msvc`.

### Architectures

| Architecture | Notes                     |
| ------------ | ------------------------- |
| aarch64      | ARM 64 bit                |
| i686         | Intel 32 bit              |
| x86_64       | Intel 64 bit              |
| arm          | ARM 32 bit                |
| armv7        | ARMv7 32 bit              |
| mips         | MIPS 32 bit               |
| mips64       | MIPS 64 bit               |
| mips64el     | MIPS 64 bit Little Endian |
| mipsel       | MIPS 32 bit Little Endian |
| powerpc      | IBM 32 bit                |
| powerpc64    | IBM 64 bit                |
| rsicv64gc    | RISC-V 64 bit             |
| s390x        | IBM Z 32 bit              |

### Vendors

| Vendor  | Notes     |
| ------- | --------- |
| pc      | Microsoft |
| apple   | Apple     |
| unknown | Unknown   |

### Operating Systems

| Operating System | Notes                            |
| ---------------- | -------------------------------- |
| darwin           | Apple's OS                       |
| linux            | Linux OS                         |
| windows          | Microsoft's OS                   |
| freebsd          | FreeBSD OS                       |
| netbsd           | NetBSD OS                        |
| illumos          | Illumos OS, a Solaris derivative |

### Environments

| Environment | Notes                      |
| ----------- | -------------------------- |
| musl        | Musl C library             |
| gnu         | GNU's C library            |
| msvc        | Microsoft Visual C library |
| freebsd     | FreeBSD's C library        |
| netbsd      | NetBSD's C library         |
| illumos     | Illumos' C library         |

When you go to the releases tab to download a particular binary, you'll need to know these four things to download a binary that runs on your system.

Now, let's start building for all these systems.

## Building Binaries for ~30 Targets 

We're going to use Github Actions, a task runner on github.com to build our binaries. Our binary is a simple `hello world` binary.

If you'd just like to look at the github actions file, it's located here: <https://github.com/Takashiidobe/rust-build-binary-github-actions/blob/master/.github/workflows/release.yml>

Conceptually, we'd like to do the following:

- Set up our target environments.
- Download the C compiler (environment) we need.
- Download a docker image of the OS we require.
- Download the rust toolchain onto docker container.
- Build the binary. 
- *Optionally* strip debug symbols.
- Publish it to the github releases tab.

We'll first start out by defining our github action and setting up the target environments:

```{.yml .numberLines}
name: release

env:
  MIN_SUPPORTED_RUST_VERSION: "1.56.0"
  CICD_INTERMEDIATES_DIR: "_cicd-intermediates"

on:
  push:
    tags:
      - '*'

jobs:
  build:
    name: ${{ matrix.job.target }} (${{ matrix.job.os }})
    runs-on: ${{ matrix.job.os }}
    strategy:
      fail-fast: false
      matrix:
        job:
          # Tier 1
          - { target: aarch64-unknown-linux-gnu      , os: ubuntu-20.04, use-cross: true }
          - { target: i686-pc-windows-gnu            , os: windows-2019                  }
          - { target: i686-unknown-linux-gnu         , os: ubuntu-20.04, use-cross: true }
          - { target: i686-pc-windows-msvc           , os: windows-2019                  }
          - { target: x86_64-apple-darwin            , os: macos-10.15                   }
          - { target: x86_64-pc-windows-gnu          , os: windows-2019                  }
          - { target: x86_64-pcwindows-msvc          , os: windows-2019                  }
          - { target: x86_64-unknown-linux-gnu       , os: ubuntu-20.04                  }
          # Tier 2 with Host Tools
          - { target: aarch64-apple-darwin           , os: macos-11.0                    }
          - { target: aarch64-pc-windows-msvc        , os: windows-2019                  }
          - { target: aarch64-unknown-linux-musl     , os: ubuntu-20.04, use-cross: true }
          - { target: arm-unknown-linux-gnueabi      , os: ubuntu-20.04, use-cross: true }
          - { target: arm-unknown-linux-gnueabihf    , os: ubuntu-20.04, use-cross: true }
          - { target: armv7-unknown-linux-gnueabihf  , os: ubuntu-20.04, use-cross: true }
          - { target: mips-unknown-linux-gnu         , os: ubuntu-20.04, use-cross: true }
          - { target: mips64-unknown-linux-gnuabi64  , os: ubuntu-20.04, use-cross: true }
          - { target: mips64el-unknown-linux-gnuabi64, os: ubuntu-20.04, use-cross: true }
          - { target: mipsel-unknown-linux-gnu       , os: ubuntu-20.04, use-cross: true }
          - { target: powerpc-unknown-linux-gnu      , os: ubuntu-20.04, use-cross: true }
          - { target: powerpc64-unknown-linux-gnu    , os: ubuntu-20.04, use-cross: true }
          - { target: powerpc64le-unknown-linux-gnu  , os: ubuntu-20.04, use-cross: true }
          - { target: riscv64gc-unknown-linux-gnu    , os: ubuntu-20.04, use-cross: true }
          - { target: s390x-unknown-linux-gnu        , os: ubuntu-20.04, use-cross: true }
          - { target: x86_64-unknown-freebsd         , os: ubuntu-20.04, use-cross: true }
          - { target: x86_64-unknown-illumos         , os: ubuntu-20.04, use-cross: true }
          - { target: arm-unknown-linux-musleabihf   , os: ubuntu-20.04, use-cross: true }
          - { target: i686-unknown-linux-musl        , os: ubuntu-20.04, use-cross: true }
          - { target: x86_64-unknown-linux-musl      , os: ubuntu-20.04, use-cross: true }
          - { target: x86_64-unknown-netbsd          , os: ubuntu-20.04, use-cross: true }
```

### Checking out our code:

```{.yml .numberLines}
    steps:
    - name: Checkout source code
      uses: actions/checkout@v2
```

### Downloading the C compiler

Most of the time, the C compiler we need is already installed, but in some cases it'll be overriden by another compiler. 

We'll need to download the correct suitable C compiler in that case: (i686-pc-windows-gnu has gcc, but it's not on the $PATH).

```{.yml .numberLines} 
    - name: Install prerequisites
      shell: bash
      run: |
        case ${{ matrix.job.target }} in
          arm-unknown-linux-*) sudo apt-get -y update ; sudo apt-get -y install gcc-arm-linux-gnueabihf ;;
          aarch64-unknown-linux-gnu) sudo apt-get -y update ; sudo apt-get -y install gcc-aarch64-linux-gnu ;;
          i686-pc-windows-gnu) echo "C:\msys64\mingw32\bin" >> $GITHUB_PATH
        esac
```

### Installing the Rust toolchain

```{.yml .numberLines}
    - name: Install Rust toolchain
      uses: actions-rs/toolchain@v1
      with:
        toolchain: stable
        target: ${{ matrix.job.target }}
        override: true
        profile: minimal # minimal component installation (ie, no documentation)
```

### Building the executable

```{.yml .numberLines}
    - name: Build
      uses: actions-rs/cargo@v1
      with:
        use-cross: ${{ matrix.job.use-cross }}
        command: build
        args: --locked --release --target=${{ matrix.job.target }}
```

### Stripping debug information from binary

```{.yml .numberLines}
    - name: Strip debug information from executable
      id: strip
      shell: bash
      run: |
        # Figure out suffix of binary
        EXE_suffix=""
        case ${{ matrix.job.target }} in
          *-pc-windows-*) EXE_suffix=".exe" ;;
        esac;
        # Figure out what strip tool to use if any
        STRIP="strip"
        case ${{ matrix.job.target }} in
          arm-unknown-linux-*) STRIP="arm-linux-gnueabihf-strip" ;;
          aarch64-pc-*) STRIP="" ;;
          aarch64-unknown-*) STRIP="" ;;
          armv7-unknown-*) STRIP="" ;;
          mips-unknown-*) STRIP="" ;;
          mips64-unknown-*) STRIP="" ;;
          mips64el-unknown-*) STRIP="" ;;
          mipsel-unknown-*) STRIP="" ;;
          powerpc-unknown-*) STRIP="" ;;
          powerpc64-unknown-*) STRIP="" ;;
          powerpc64le-unknown-*) STRIP="" ;;
          riscv64gc-unknown-*) STRIP="" ;;
          s390x-unknown-*) STRIP="" ;;
          x86_64-unknown-freebsd) STRIP="" ;;
          x86_64-unknown-illumos) STRIP="" ;;
        esac;
        # Setup paths
        BIN_DIR="${{ env.CICD_INTERMEDIATES_DIR }}/stripped-release-bin/"
        mkdir -p "${BIN_DIR}"
        BIN_NAME="${{ env.PROJECT_NAME }}${EXE_suffix}"
        BIN_PATH="${BIN_DIR}/${BIN_NAME}"
        TRIPLET_NAME="${{ matrix.job.target }}"
        # Copy the release build binary to the result location
        cp "target/$TRIPLET_NAME/release/${BIN_NAME}" "${BIN_DIR}"
        # Also strip if possible
        if [ -n "${STRIP}" ]; then
          "${STRIP}" "${BIN_PATH}"
        fi
        # Let subsequent steps know where to find the (stripped) bin
        echo ::set-output name=BIN_PATH::${BIN_PATH}
        echo ::set-output name=BIN_NAME::${BIN_NAME}
```

### And uploading to Github 

```{.yml .numberLines}
    - name: Create tarball
      id: package
      shell: bash
      run: |
        PKG_suffix=".tar.gz" ; case ${{ matrix.job.target }} in *-pc-windows-*) PKG_suffix=".zip" ;; esac;
        PKG_BASENAME=${PROJECT_NAME}-v${PROJECT_VERSION}-${{ matrix.job.target }}
        PKG_NAME=${PKG_BASENAME}${PKG_suffix}
        echo ::set-output name=PKG_NAME::${PKG_NAME}
        PKG_STAGING="${{ env.CICD_INTERMEDIATES_DIR }}/package"
        ARCHIVE_DIR="${PKG_STAGING}/${PKG_BASENAME}/"
        mkdir -p "${ARCHIVE_DIR}"
        mkdir -p "${ARCHIVE_DIR}/autocomplete"
        # Binary
        cp "${{ steps.strip.outputs.BIN_PATH }}" "$ARCHIVE_DIR"
        # base compressed package
        pushd "${PKG_STAGING}/" >/dev/null
        case ${{ matrix.job.target }} in
          *-pc-windows-*) 7z -y a "${PKG_NAME}" "${PKG_BASENAME}"/* | tail -2 ;;
          *) tar czf "${PKG_NAME}" "${PKG_BASENAME}"/* ;;
        esac;
        popd >/dev/null
        # Let subsequent steps know where to find the compressed package
        echo ::set-output name=PKG_PATH::"${PKG_STAGING}/${PKG_NAME}"
    - name: "Artifact upload: tarball"
      uses: actions/upload-artifact@master
      with:
        name: ${{ steps.package.outputs.PKG_NAME }}
        path: ${{ steps.package.outputs.PKG_PATH }}

    - name: Check for release
      id: is-release
      shell: bash
      run: |
        unset IS_RELEASE ; if [[ $GITHUB_REF =~ ^refs/tags/v[0-9].* ]]; then IS_RELEASE='true' ; fi
        echo ::set-output name=IS_RELEASE::${IS_RELEASE}
    - name: Publish archives and packages
      uses: softprops/action-gh-release@v1
      if: steps.is-release.outputs.IS_RELEASE
      with:
        files: |
          ${{ steps.package.outputs.PKG_PATH }}
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }} 
```

And after building this github actions file, we find that... 3 targets fail to build.

`x86_64-unknown-freebsd`, `x86_64-unknown-illumos`, `powerpc-unknown-linux-gnu`.

Luckily, the error message that cross provides gives us a clear indication of what to fix. Cross does not provide a proper image, so it gets confused, defaults to the toolchain it's running on (ubuntu 20.04), and the linker cannot find the proper libraries required. Easy to fix: Add a `Cross.toml` file to the root of the project with docker images for the particular targets, and build again.

```{.toml .numberLines} 
[target.x86_64-unknown-freebsd]
image = "svenstaro/cross-x86_64-unknown-freebsd"

[target.powerpc64-unknown-linux-gnu]
image = "japaric/powerpc64-unknown-linux-gnu"
```

You'll notice that illumos is missing here -- I couldn't find a suitable docker image to build it on docker hub, so I gave up. If you find one, let me know and i'll update this article.

## Results

Out of the 29 architectures provided in Tier 1 and Tier 2 with host tools, it was easy enough to build a binary for 28 architectures (We only need a solaris/illumos docker image to build for the last one).

That's pretty good, given that this only took a couple of hours to test out. I hope Rust continues to support this many architectures into the future, and Github Actions keeps being a good platform to make releases for.

If you'd like to take the repo for yourself to build rust binaries on releases for 28 architectures, feel free to clone/fork the repo here: <https://github.com/Takashiidobe/rust-build-binary-github-actions>
