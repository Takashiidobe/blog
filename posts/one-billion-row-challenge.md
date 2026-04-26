---
title: "The One Billion Row Challenge"
date: 2026-04-25T16:30:34-04:00
draft: false
---

# The One Billion Row Challenge

A couple of years ago, the [1 Billion Row Challenge](https://1brc.dev/)
got popular. The challenge is to write a program that reads a text file
with the format of: `$CITY_NAME;$TEMP\n` of some size, and then for each
city, the program should print out the min, mean, and max values per
city, alphabetically ordered.

So if you have:

```
Hamburg;12.0
Hamburg;34.2
```

You would condense this down to:

```
Hamburg;12.0;23.1;34.2
   ^      ^    ^    ^
 city    min  mean max
```

And print that out.

I decided to do this in Rust, and this post is what I learned.

## Preliminaries

Since I knew I wanted to try out a few different methods, to start off
with I defined a trait so I would only have to rewrite the core logic.

```rust
pub type Temp = i16;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StationResult {
    pub station: String,
    pub min: Temp,
    pub mean: Temp,
    pub max: Temp,
}

pub trait Solver: Default {
    fn process(&mut self, station: &str, temp: Temp);
    fn process_bytes(&mut self, station: &[u8], temp: Temp) -> io::Result<()> {
        let station = std::str::from_utf8(station).map_err(|error| {
            io::Error::new(
                io::ErrorKind::InvalidData,
                format!("invalid station name UTF-8: {error}"),
            )
        })?;
        self.process(station, temp);
        Ok(())
    }

    fn finish(self) -> Vec<StationResult>;
}
```

As well, I needed to keep the stats for each station:

```rust
pub type Temp = i16;
pub type TempSum = i64;
pub type Count = u32;

#[derive(Default, Clone, Copy)]
pub(crate) struct Stats {
    pub(crate) sum: TempSum,
    pub(crate) count: Count,
    pub(crate) min: Temp,
    pub(crate) max: Temp,
}

impl Stats {
    pub(crate) fn add(&mut self, temp: Temp) {
        if self.count == 0 {
            self.min = temp;
            self.max = temp;
        } else {
            self.min = self.min.min(temp);
            self.max = self.max.max(temp);
        }

        self.sum += TempSum::from(temp);
        self.count += 1;
    }

    pub(crate) fn into_result(self, station: String) -> StationResult {
        StationResult {
            station,
            min: self.min,
            mean: round_mean_tenths(self.sum, self.count),
            max: self.max,
        }
    }
}
```

With a helper for reading input:

```rust
pub fn process_measurements<R, S>(reader: R, solver: &mut S) -> io::Result<()>
where
    R: BufRead,
    S: Solver,
{
    for line in reader.lines() {
        let line = line?;
        let Some((station, temp)) = line.split_once(';') else {
            continue;
        };

        solver.process(station, parse_temperature_tenths(temp)?);
    }

    Ok(())
}
```

A helper for writing output:

```rust
pub fn write_results_to_path(path: Option<&str>, results: &[StationResult]) -> io::Result<()> {
    match path {
        Some(path) => {
            let file = File::create(path)?;
            let writer = BufWriter::new(file);
            write_results(writer, results)
        }
        None => {
            let stdout = io::stdout();
            let writer = stdout.lock();
            write_results(writer, results)
        }
    }
}
```

And finally, running the solver:

```rust
pub fn run_solver<S>(input_path: &str, output_path: Option<&str>) -> io::Result<()>
where
    S: Solver,
{
    let file = File::open(input_path).map_err(|error| not_found_error(input_path, error))?;
    let reader = BufReader::with_capacity(8 * 1024 * 1024, file);
    let mut solver = S::default();

    input::process_measurements(reader, &mut solver)?;
    output::write_results_to_path(output_path, &solver.finish())
}
```

As well, I wanted to create a couple of things. First off, I needed
`cargo flamegraph` to see where time was being spent, and I wrote a
script so I could generate input of different sizes. The 1 billion rows
would be wasteful to do my target runs on, so I took the weather data
from the one billion rows repo and generated a million row sample to run
on.

## The Easiest Solution (BTreeMap)

First off, let's start off with the basics. The simplest solution I
could think of was to:

1. For each line, split at the ';' character.
    - The left side is the station name.
    - The right side is the temperature. 
    - Take the temperature, and then record the current total, current
      count, current minimum, and current maximum.
2. Sort the cities.
3. Calculate the mean by doing sum / count;
4. Print out "{city};{min};{mean};{max}" for each city.

You know what's better than sorting at the end? Having a data structure
do it for you. So at first, I used a `BTreeMap`. With the `Solver`
trait, I just needed to implement `process` and `finish`.

```rust
#[derive(Default)]
pub struct BasicBTreeMapSolver {
    stats_by_station: BTreeMap<String, Stats>,
}

impl Solver for BasicBTreeMapSolver {
    fn process(&mut self, station: &str, temp: Temp) {
        self.stats_by_station
            .entry(station.to_string())
            .or_default()
            .add(temp);
    }

    fn finish(self) -> Vec<StationResult> {
        self.stats_by_station
            .into_iter()
            .map(|(station, stats)| stats.into_result(station))
            .collect()
    }
}
```

This solution crunches through one million rows in 218ms on my
Ryzen 5 7600 CPU.

Not bad but we could do better. Taking a look at the flamegraph here,
there's not too much to say, but it looks like the btreemap logic itself
is taking the longest amount of time, so we should tackle that first.

<object type="image/svg+xml" data="../assets/obrc/btreemap.svg" width="100%" height="100%">
</object>


## The Next Solution (HashMap)

BTreeMap is slow for this solution because we don't need a sorted order
all the time, just at the end. To do that, we can fall back to good old
HashMap and sort once at the end.

And with that:

```rust
impl Solver for BasicHashMapSolver {
    fn process(&mut self, station: &str, temp: Temp) {
        if let Some(stats) = self.stats_by_station.get_mut(station) {
            stats.add(temp);
        } else {
            let mut stats = Stats::default();
            stats.add(temp);
            self.stats_by_station.insert(station.to_string(), stats);
        }
    }

    fn finish(self) -> Vec<StationResult> {
        let mut results: Vec<_> = self
            .stats_by_station
            .into_iter()
            .map(|(station, stats)| stats.into_result(station))
            .collect();

        results.sort_unstable_by(|left, right| left.station.cmp(&right.station));
        results
    }
}
```

This about halves the run time, to 110ms. I was expecting more
of a modest improvement, but this is pretty nice. The next chunk I see
taking a lot of time is read_line, so we can work on that next.

<object type="image/svg+xml" data="../assets/obrc/hashmap.svg" width="100%" height="100%">
</object>

## Memory Mapping

The next bottleneck looked to be I/O: BufReader was taking the most
amount of time. The Bufreader already reads in chunks, but we want to
avoid going back to the kernel for reads. Memory mapping is one way to
do that.

All we have to do is change our input hook to memory map our input file.

```rust
pub fn run_solver_mmap<S: Solver>(input_path: &str, output_path: Option<&str>) -> io::Result<()> {
    let file = File::open(input_path)?;
    let mmap = unsafe { MmapOptions::new().map(&file)? };
    let mut solver = S::default();
    input::process_measurements_bytes(&mmap, &mut solver)?;
    output::write_results_to_path(output_path, &solver.finish())
}
```

This gets us an even faster runtime of 79ms.

<object type="image/svg+xml" data="../assets/obrc/hashmap-mmap.svg" width="100%" height="100%">
</object>

## More changes

At this point I was pretty satisfied. Memory mapping the input file +
using a HashMap was already pretty good. But the flamegraph does show
that `parse_temperature_tenths_bytes` is pretty slow (32% of runtime),
so let's dig into that.

The current implementation is: 

```rust
fn parse_temperature_tenths_bytes(value: &[u8]) -> io::Result<Temp> {
    let negative = value.first() == Some(&b'-');
    let digits = if negative { &value[1..] } else { value };
                                                                                                                              
    if digits.len() < 3 || digits[digits.len() - 2] != b'.' {
        return Err(invalid_temperature_bytes(value));
    }
                                                                                                                       
    let whole = &digits[..digits.len() - 2];
    let fraction = digits[digits.len() - 1];
    if whole.is_empty()
        || !whole.iter().all(|byte| byte.is_ascii_digit())
        || !fraction.is_ascii_digit()
    {
        return Err(invalid_temperature_bytes(value));
    }
                                                                                                                       
    let mut temp = Temp::from(fraction - b'0');
    let mut multiplier = 10;
    for &digit in whole.iter().rev() {
        temp += Temp::from(digit - b'0') * multiplier;
        multiplier *= 10;
    }
                                                                                                                       
    Ok(if negative { -temp } else { temp })
}
```

This has a few branches and error checking. We can make this branchless
by exploiting the fact that there are only 4 formats. We just need to
check if the first character is the negative sign, then grab the
fractional part from the end, and otherwise grab the number itself. We
can then recreate the value itself that way, fully branchless.

```rust
fn parse_temperature_tenths_bytes(value: &[u8]) -> io::Result<Temp> {
    let neg = (value[0] == b'-') as usize;
    let frac = (value[value.len() - 1] - b'0') as Temp;
    let ones = (value[value.len() - 3] - b'0') as Temp;
    let has_tens = (value.len() - neg > 3) as Temp;
    let tens = has_tens * (value[neg] - b'0') as Temp;
    let sign = 1 - 2 * neg as Temp;
    Ok(sign * (tens * 100 + ones * 10 + frac))
}
```

This has two advantages: one, dropping the runtime to 72ms, a nice
improvement, but also dropping the variance between runs. We used to
have about 5-8ms variance, but now this is less than <1ms between runs,
since branchless solutions are more consistent.


<object type="image/svg+xml" data="../assets/obrc/hashmap-mmap-branchless-bytes.svg" width="100%" height="100%">
</object>

## Handle the bytes

Why bother having strings at all? Why not index a city by its bytes? We
can do that and combined with a faster hashmap (Fnv), I got a 60ms
runtime on my computer. 

```rust
pub struct FnvBytesSolver {
    stats_by_station: FnvHashMap<Vec<u8>, Stats>,
}

impl Solver for FnvBytesSolver {
    fn process_bytes(&mut self, station: &[u8], temp: Temp) -> io::Result<()> {
        if let Some(stats) = self.stats_by_station.get_mut(station) {
            stats.add(temp);
        } else {
            let mut stats = Stats::default();
            stats.add(temp);
            self.stats_by_station.insert(station.to_vec(), stats);
        }
        Ok(())
    }

    fn finish(self) -> Vec<StationResult> {
        let mut results = Vec::with_capacity(self.stats_by_station.len());
        for (station, stats) in self.stats_by_station {
            let station = String::from_utf8(station).expect("valid UTF-8");
            results.push(stats.into_result(station));
        }
        results.sort_unstable_by(|l, r| l.station.cmp(&r.station));
        results
    }
}
```

<object type="image/svg+xml" data="../assets/obrc/fnv-bytes-mmap.svg" width="100%" height="100%">
</object>

## A Dead end

At this point, I had about hit wits end. About 48% of runtime was in
FnvHasher's `get_mut`, and otherwise about 17% of runtime was in
`float_to_decimal_common_exact`. 

So the next two things are to remove the hashmap and fix the output
formatting.

The biggest impact would be to rip out the hashmap itself and come up
with a custom flat hashmap.

```rust
fn fingerprint(key: &[u8]) -> u64 {
    let mut buf = [0u8; 8];
    let n = key.len().min(8);
    buf[..n].copy_from_slice(&key[..n]);
    u64::from_le_bytes(buf)
}

fn table_index(fp: u64, key_len: usize) -> usize {
    let h = fp ^ (key_len as u64).wrapping_shl(17);
    let h = h ^ (h >> 30);
    let h = h.wrapping_mul(0xbf58476d1ce4e5b9);
    let h = h ^ (h >> 27);
    let h = h.wrapping_mul(0x94d049bb133111eb);
    let h = h ^ (h >> 31);
    (h as usize) & TABLE_MASK
}

const TABLE_SIZE: usize = 1 << 17; 

struct Slot<'a> {
    fingerprint: u64,
    key: &'a [u8],
    stats: Stats,
}

struct FlatTable<'a> {
    slots: Box<[Slot<'a>]>,
}

impl<'a> FlatTable<'a> {
    fn update(&mut self, key: &'a [u8], temp: Temp) {
        let fp = fingerprint(key);
        let mut idx = table_index(fp, key.len());
        loop {
            let slot = &mut self.slots[idx];
            if slot.key.is_empty() {               
                slot.fingerprint = fp;
                slot.key = key;
                slot.stats = Stats::default();
                slot.stats.add(temp);
                return;
            }
            if slot.fingerprint == fp && slot.key == key {
                slot.stats.add(temp);
                return;
            }
            idx = (idx + 1) & TABLE_MASK; 
        }
    }
}
```

The second thing is to fix up the output formatting:

```rust
pub fn format_temperature_tenths(temp: Temp) -> String {
    format!("{:.1}", temp as f64 / 10.0)
}
```

Into this: avoids the 17% of runtime in outputting the float:

```rust
pub fn format_temperature_tenths(temp: Temp) -> String {
    let neg = temp < 0;
    let abs = temp.unsigned_abs();
    if neg {
        format!("-{}.{}", abs / 10, abs % 10)
    } else {
        format!("{}.{}", abs / 10, abs % 10)
    }
}
```

With both of those fixes, we get a dramatic improvement to 36ms runtime.

<object type="image/svg+xml" data="../assets/obrc/fast.svg" width="100%" height="100%">
</object>

## Parallelization

After this, it's pretty unclear how to improve this single-threaded
solution any more. I decided to drop --no-inline from my cargo
flamegraphs since it said 90% of runtime was in `process_bytes` and the
rest was inlined into it. But looking at the flamegraph while counting
inlining, it seems like it's doing about the minimal amount of work
required. 

A simple way to use parallelism is to cut the input into equal sized
chunks by the number of threads, and then join at the end.

To chunk:

```rust
fn chunks_for_threads(bytes: &[u8], threads: usize) -> Vec<(usize, usize)> {
    let len = bytes.len();
    let threads = threads.min(len);
    let mut chunks = Vec::with_capacity(threads);
    let mut start = 0;
    for index in 0..threads {
        if start >= len { break; }
        let end = if index + 1 == threads {
            len
        } else {
            align_end_to_line(bytes, len * (index + 1) / threads)
        };
        if start < end { chunks.push((start, end)); }
        start = end;
    }
    chunks
}

fn align_end_to_line(bytes: &[u8], pos: usize) -> usize {
    memchr(b'\n', &bytes[pos..]).map_or(bytes.len(), |offset| pos + offset + 1)
}
```

To run in parallel:

```rust 
pub fn run_parallel_borrowed_mmap(input_path: &str, output_path: Option<&str>, threads: usize) -> io::Result<()> {
    let file = File::open(input_path)?;
    let mmap = unsafe { MmapOptions::new().map(&file)? };
    let chunks = chunks_for_threads(&mmap, threads.max(1));

    let local_tables = thread::scope(|scope| {
        let handles: Vec<_> = chunks.iter().map(|&(start, end)| {
            let bytes = &mmap[start..end];
            scope.spawn(move || {
                let mut table = FlatTable::new();
                process_bytes(bytes, &mut table);
                table
            })
        }).collect();

        handles.into_iter()
            .map(|h| h.join().expect("worker thread panicked"))
            .collect::<Vec<_>>()
    });

    let mut table = FlatTable::new();
    for local in local_tables {
        table.merge_from(&local);
    }
    // sort and write
}
```

To merge:

```rust
fn merge_from(&mut self, other: &FlatTable<'a>) {
    for &slot in other.slots.iter() {
        if slot.key.is_empty() { continue; }
        let mut idx = table_index(slot.fingerprint, slot.key.len());
        loop {
            let target = &mut self.slots[idx];
            if target.key.is_empty() {
                *target = slot;
                break;
            }
            if target.fingerprint == slot.fingerprint && target.key == slot.key {
                target.stats.sum += slot.stats.sum;
                target.stats.count += slot.stats.count;
                target.stats.min = target.stats.min.min(slot.stats.min);
                target.stats.max = target.stats.max.max(slot.stats.max);
                break;
            }
            idx = (idx + 1) & TABLE_MASK;
        }
    }
}
```

With that, we get a runtime of about 21ms.

<object type="image/svg+xml" data="../assets/obrc/fast-par.svg" width="100%" height="100%">
</object>

## Conclusion

In the end, we started out with about a 220ms runtime and got it down
all the way to 21ms, about a 10x improvement. The first improvement of
just using a hashmap did most of the work, down to 110ms, and each
respective improvement took more and more work to do for less and less
gain. 

Cargo flamegraph made it easy to find hotspots, but it doesn't tell you
how to improve your solution -- that requires hard thought, but it's
useful to figure out where there's room to improve.
