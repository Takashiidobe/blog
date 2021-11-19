---
title: "Write RFCs"
date: 2021-06-03T21:00:10-04:00
draft: false 
---

RFCs are `Requests for Comments`, popularized by the Internet Engineering Task Force (IETF) which develops and promotes standards for the internet.

## Defining an RFC

Much has been said about RFCs (Including [RFC 3](https://datatracker.ietf.org/doc/html/rfc3) which outlines how to write an RFC for the IETF), but let's read through the main points of RFC 3.

- RFCs can be on thoughts, suggestions, etc. relating to the subject (The internet in this case)
- RFCs should be timely, rather than polished 
- RFCs do not require examples 
- RFCs can be as short or as long as needed

According to RFC 3, RFCs should have the following information:

1. "Network Working Group Request for Comments:" X (where X is the number of the RFC)
2. Author and Affiliation
3. Date
4. Title (Does not need to be unique)

## Benefits of RFCs

According to [6 Lessons I learned while implementing technical RFCs as a decision making tool](https://buriti.ca/6-lessons-i-learned-while-implementing-technical-rfcs-as-a-management-tool-34687dbf46cb), After implementing RFCs in his organization, Juan Pablo Buriticá picked RFCs for the following reasons:

- enable individual contributors to make decisions for systems they’re responsible for
- allow domain experts to have input in decisions when they’re not directly involved in building a particular system
- manage the risk of decisions made
- include team members without it becoming design by committee
- have a snapshot of context for the future
- be asynchronous
- work on multiple projects in parallel

In my company, RFCs allow us to propose ideas to improve processes, development experience, the product, with low risk of retribution and without the anxiety of giving a presentation. Q & A is relaxed for both the author of the RFC and those writing comments, as they are allowed to proceed asynchronously, without either party feeling pressured to have all the answers right away. They're also a written record of the thoughts of the authors and reviewers throughout the lifecycle of the proposal, and serve as a historical artifact for reflection (if a proposal that sounded good didn't turn out so well, why didn't it work out?)

## Implementing RFCs

Oxide Computer explained how they do RFCs (which they call RFDs, Requests for Discussions) here: [RFDs at Oxide Computer](https://oxide.computer/blog/rfd-1-requests-for-discussion)

At Oxide, RFDs are appropriate for the following cases:

- Add or change a company process
- An architectural or design decision for hardware or software
- Change to an API or command-line tool used by customers
- Change to an internal API or tool
- Change to an internal process
- A design for testing

Oxide has a few twists, like adding a state as metadata (an RFD can be in the Prediscussion, Ideation, Discussion, Published, Committed, or Abandoned state), and go into detail about integrating their RFD system into git.

## A Template for RFCs

Following what Oxide did, I made a template repository for RFCs.

You can find it here: [Template RFC Repository](https://github.com/Takashiidobe/rfcs)
