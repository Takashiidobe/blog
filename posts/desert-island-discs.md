---
title: "Desert Island Discs"
date: 2021-09-06T22:47:22-05:00
draft: false 
---

What would be the eight software programs you would take to a deserted island? To me, I'd need the following: an OS, libc, a C compiler, a shell, a database, a networking stack, unix utils, a lisp interpreter, and an editor. I've decided to try my hand at writing these to get better at low-level programming, and learn the stack a bit better. It's a good challenge, but in the interest of time and sanity I will be putting lots of asterisks next to each disc. 

## An Operating System

I'm not going to write an OS. Maybe I'll write some signals and system calls, but that's about it.

## A C Compiler

I'll write a C Compiler that implements **most** of C89, that emits assembly of the computer I'm working on.

## Libc

A limited subset of libc would be nice. Plauger has a good book on implementing a C89 compliant libc, which I will most likely follow, along with looking at some code from musl.

As well, I'll be writing some crypto and data structures to help with other tasks down the road.

## A shell

Nothing like bash. I've decided to write a small shell and relegate the rest to the shell I'm currently working on.

## A Database

A simple serializable Key-Value database should suffice. Will need to learn B-Trees, though.

## A Networking Stack

I'll learn how to write an HTTP Client and Server using the sockets library.

## Unix Utils

I'll write some basic unix utils, striving for some partial POSIX compliance.

## A Lisp Interpreter

Lisp, being one of the simplest languages, allows me to write a higher level language from C. That makes it a great target for an interpreter to learn from.

## A Text Editor

Vim is my text editor of choice; it'd be nice to be able to write an editor with some similar functionality.
