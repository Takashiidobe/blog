---
title: "Writing an SQL DB isn't hard"
date: 2023-07-27T09:25:36-04:00
draft: true
---

In this post, we'll write an "SQL" DB that has support for a subset of `SELECT`, and discuss how to extend it in the future.

Let's start off by discussing what an SQL database does.

An SQL DB takes input from the user in the form of an SQL query, parses it into an AST, and then returns the result to
