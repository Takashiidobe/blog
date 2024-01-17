---
title: "How fast are computers these days"
date: 2024-01-16T08:50:36-05:00
draft: false
---

I've been doing a lot of reading about distributed systems, but I've never known how fast hardware goes these days. Some common advice like "I/O is slow" or "system calls are slow" might not matter that much, depending on the performance requirements of the system that's using them.

General performance numbers are useful for building distributed systems -- let's say you have a system with 1PB of data and you want to backup all that data to one node, where you can write to disk at 1GB/s. How long does it take to back up the whole node? That would take about 10 days to complete (1PB / 1GB) is 1M, and 1M seconds is about 10 days. If we were using HDDs from 20 years ago instead of SSDs, where writes might be closer to 40MB/s, it would take closer to 250 days, which is really crazy.

Armed with this information, we might say a total outage cannot happen, or we carefully design the system to partition the data so backups can happen in parallel, where if we have 1000 nodes, then our 10 day backup might take 10 / 1000 days, or closer to 90 seconds.

For a twist, I decided to benchmark my phone (a Samsung S10) vs my personal laptop (a Framework laptop with a 12th gen intel i5-1240p processor, 32GB of DDR4-3200 RAM, and a 2TB Western Digital SN750). The S10 has a value of about $200 used these days, and the laptop about $1000. So, we can also see how much money it would cost to build a system using these parts (although I assume building a system with NUCs or the like would be much more cost efficient), we can get a ballpark estimation of how much certain distributed systems would cost to build. As well, I'll put down my guesses for how fast I thought each benchmark would be for my phone and my laptop, and see how far off I was. In the end, we'll discuss some in the wild systems and see how feasible it would be to build them.

## HTTP Servers

The communication layer of a service might use HTTP. Thus, I wanted to benchmark a "hello world" HTTP service to see how fast a networked service could run, given it does no work.

I assumed my laptop would run about 100k req/s, with around 10 microsecond latency, and my phone would do around 10k req/s, with 100 microsecond latency.

Try to guess how fast each device was:

The computer had these results:

```
Running 5s test @ http://localhost:3000
  256 goroutine(s) running concurrently
975712 requests in 4.929485946s, 105.15MB read
Requests/sec:		197933.82
Transfer/sec:		21.33MB
Avg Req Time:		1.293361ms
Fastest Request:	21.095µs
Slowest Request:	67.116949ms
Number of Errors:	0
```

And the phone:

```
Running 5s test @ http://localhost:3000
  32 goroutine(s) running concurrently
107649 requests in 4.909044953s, 11.29MB read
Requests/sec:		21928.71
Transfer/sec:		2.30MB
Avg Req Time:		1.459274ms
Fastest Request:	85.677µs
Slowest Request:	48.922239ms
Number of Errors:	0
```

The laptop had about 200k req/s and the phone had about 20k req/s.
Both were about twice as fast as I expected.

So, if we had to create a "Hello world" server and reach 1M req/s, it would take 50 phones or 5 laptops. The 50 phones would cost $10000, and the 5 laptops would cost about $5000. Computers are cheaper.

## Redis

What if we put a cache in front of our servers? How fast could it respond?

Since redis is single-threaded and in-memory, it should have similar numbers to the HTTP server.

I would assume that it would perform the same as the HTTP servers, since they'd be doing about the same amount of work: ~200k req/s for the laptop and ~20k req/s for the phone.

The laptop ran at ~200k for read, write, ping.

The phone ran at ~40k req/s for read, write, ping.

Pretty good -- if we could hold our dataset in memory, we could respond with 200k req/s.

## Sqlite

We'll need a database to store our data. Let's say we use sqlite, and benchmark it, using row sizes of 1000B.

I assume that we can write about 50k/second rows on the laptop and 10k rows/second on the phone.

The laptop:

Batching 1000 writes at a time:

```sh
$ ./sqlite-bench -batch-count 1000 -batch-size 1000 -row-size 1000 -journal-mode wal -synchronous normal ./bench.db

Inserts:   1000000 rows
Elapsed:   7.824s
Rate:      127817.265 insert/sec
File size: 1026584576 bytes
```

Writing 1 row at a time:

```sh
$ ./sqlite-bench -batch-count 1000000 -batch-size 1 -row-size 1000 -journal-mode wal -synchronous normal ./bench.db

Inserts:   1000000 rows
Elapsed:   43.839s
Rate:      22810.910 insert/sec
File size: 1026584576 bytes
```

The phone:

Batching 1000 writes at a time:

```sh
$ ./sqlite-bench -batch-count 1000 -batch-size 1000 -row-size 1000 -journal-mode wal -synchronous normal ./bench.db

Inserts: 1000000 rows
Elapsed: 66.006s
Rate: 15150.53 insert/sec
File size: 1026584576 bytes
```

Writing 1 row at a time:

```sh
$ ./sqlite-bench -batch-count 1000000 -batch-size 1 -row-size 1000 -journal-mode wal -synchronous normal ./bench.db

Inserts:   1000000 rows
Elapsed:   200.473s
Rate:      4884.369 insert/sec
File size: 1026584576 bytes
```

Here we see the phone's weakness -- its disk. Inserting row by row, the phone only can write 5k rows/s, whereas the computer can do about 20k rows/s, probably due to the phone having a flash disk and the computer having an SSD.

## Disk

Since the sqlite bench uncovered the weakness of the phone's disk, lets test out some numbers for the file system:

I decided to benchmark sequential reads + writes for both and with fsync for the writes. Since I used `fio` as my tool, and it supports `io_uring`, I gave that a shot on my laptop. Android doesn't support `io_uring` for security reasons, so I only ran `io_uring` on the computer.

I'd expect about 4GB/s read and 3GB/s write on the computer (since that's what the SSD is rated at) and maybe 1GB/s read and 200MB/s write for the phone?

The numbers looked like this, with a blocksize of 1MB and running 8 jobs in parallel, which seemed to be the best, throughput wise:

Computer:

| job name                      | p50     | p90    | p99     | p99.99   | throughput                     |
|-------------------------------|---------|--------|---------|----------|--------------------------------|
| sync sequential read          | 113μs   | 5014μs | 33424μs | 37487μs  | 3387MB/s                       |
| sync sequential write - fsync | 169μs   | 529μs  | 1319μs  | 333448μs | 2830MB/s                       |
| sync sequential write + fsync | 775μs   | 1090μs | 1369μs  | 2147μs   | 1714MB/s                       |
| sync readwrite - fsync        | 204μs   | 416μs  | 865μs   | 14222μs  | Read: 2556MB/s Write: 2665MB/s |
| sync readwrite + fsync        | 416μs   | 832μs  | 2769μs  | 9372μs   | Read: 1052MB/s Write: 1093MB/s |

Phone:

With a blocksize of 256k and running 8 jobs in parallel:


| job name                      | p50     | p90     | p99     | p99.99   | throughput                     |
|-------------------------------|---------|---------|---------|----------|--------------------------------|
| sync sequential read          | 1549μs  | 4490μs  | 4752μs  | 22152μs  | 866MB/s                        |
| sync sequential write - fsync | 18482μs | 39584μs | 89654μs | 109577μs | 100MB/s                        |
| sync sequential write + fsync | 510μs   | 865μs   | 1729μs  | 1860μs   | 86.3MB/s                       |
| sync readwrite - fsync        | 314μs   | 1926μs  | 41681μs | 41681μs  | Read: 77.4MB/s Write: 75.5MB/s |
| sync readwrite + fsync        | 379μs   | 717μs   | 10421μs | 10421μs  | Read: 38.5MB/s Write: 41.4MB/s |

The phone was substantially slower than I expected.

## Hashing

I was expecting about 400MB/s hashing on the laptop and about 100MB/s hashing on the phone for a non-cryptographic hash, and ~40MB/s for a cryptographic hash on a laptop, and 10MB/s on a phone.

Laptop:

- sha3-256:          56.14 MiB/sec
- md5:              404.15 MiB/sec
- sha1:             432.36 MiB/sec
- xxhash:          1827.80 MiB/sec
- murmur3:         1826.07 MiB/sec
- jhash:           1542.84 MiB/sec
- fnv:             3720.28 MiB/sec
- crc32c:          4682.73 MiB/sec

Phone:

- sha3-256:         217.77 MiB/sec
- md5:              391.14 MiB/sec
- sha1:             334.32 MiB/sec
- xxhash:          2037.18 MiB/sec
- murmur3:         1328.81 MiB/sec
- jhash:           1754.98 MiB/sec
- fnv:             2928.83 MiB/sec
- crc32c:         14255.49 MiB/sec

I could not have been more wrong.

The phone hashes very quickly compared to the laptop, maybe because of some hardware instructions?

## Networks

The Computer can support 2.5Gbit/s ethernet, and the phone can support 2000Mb/s DL and 316Mb/s UL, which is pretty fast, even faster than disk, so network probably won't be the bottleneck.

## Talking about Systems

With some numbers to work with, let's talk about some famous products and their requirements.

### Google Search

In 2006, according to [Source](http://googlesystem.blogspot.com/2006/09/how-much-data-does-google-store.html), the google search engine contained about 850TB of information.

Assuming google search needs to handle 100k requests/second, and each request would return 4KB of data, our bandwidth requirement would be 400MB/s. That's feasible to handle on a few laptops.

Assuming that we didn't have an index at all. We would need to somehow read 850TB of data per request -- even with a sequential read speed of ~3GB/s, each request would take 3 days of compute time to complete. Since we have to handle 100k reads a second, and each request takes 3 days of compute time, in one second we would need to spend 866 years of compute time to serve reads. One second of requests would also require 100,000 computers * the amount of seconds in three days, or about 250,000, for 2.5B computers required to serve google search. At $800/computer, this would be $2.5T, 1/10th the GDP of the US. Crazy.

However, if the computer only needed to search a gigabyte of data on disk to fetch a result, since a laptop's SSD can read about 3GB/s sequentially, even having to search on disk for 100MB would take 30ms. Even worse would be the computer requirement -- each machine would only be able to handle 30 req/s, so 3,000 laptops would be required at any given time to serve all search requests.

If we can lower the seeking on disk to only 1MB, we could handle 3,000 req/s, and only require 30 laptops -- so having a fast index matters a lot. It would be even better if we could search in RAM, where memory throughput is closer to 25GB/s. If the entire index was in-memory and needed to read 1MB of data, each laptop would be able to handle 25,000 req/s, and we'd only need 4 laptops.

### Amazon S3

According to [Source](https://www.allthingsdistributed.com/2023/07/building-and-operating-a-pretty-big-storage-system.html) Amazon S3 holds 280 trillion objects, and handles about 100 million req/s. S3 sends 125 billion events per day (1.25M req/s), and S3 handles 4 billion checksum computations per second.

Assuming that's 80M reads and 20M writes, each of 1MB, that would involve 80TB/s of reads, and 20TB/s of writes. For the disk usage alone, you'd need ~7,000 laptops to handle the writes, and ~27,000 laptops to handle the reads every second. But assuming we use 2.5Gb internet, at ~300MB/s, we'd need 10 times that amount, or 70,000 laptops to handle the writes and 270,000 laptops for the reads.

For the hashing, assuming each hash is over 1MB of data, would require hashing 4PB/s of data. Using xxhash at 2GB/s would require 2,000,000 laptops to just hash the data. Servers can hash xxhash data at over 100GB/s, so I assume amazon uses those to reduce the computer requirement to a modest less than 400,000.

## Conclusion

While going through this I learned a lot about how fast my computers are -- they can handle hosting lots of services. Also, computers are really cheap -- an 8GB RAM, 80GB SSD instance on hetzner is ~$5/month, and the equivalent NUC would cost ~$100 to own, and these can handle thousands of requests per second at the very least, more than enough for the large majority of services.
