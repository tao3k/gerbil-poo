# V19 runtime performance audit

The object-scale and table-count benchmarks measure runtime CPU time; the
wide-slot construction A/B below measures wall time. None claims a separate
AOT optimization. Build and benchmark with the same Gerbil V19
toolchain, using an isolated `GERBIL_PATH` so installed package artifacts are
not mixed with this checkout:

```sh
bench_path=$(mktemp -d /tmp/poo-v19-runtime.XXXXXX)
GERBIL_PATH="$bench_path" just build
GERBIL_PATH="$bench_path" just test
GERBIL_PATH="$bench_path" gxc -d "$bench_path" -exe -o "$bench_path/object-scale" t/object-scale-benchmark.ss
GERBIL_PATH="$bench_path" gxc -d "$bench_path" -exe -o "$bench_path/count-scale" t/count-performance-benchmark.ss
"$bench_path/object-scale"
"$bench_path/count-scale"
```

Check that the test output ends with `OK`; this V19 `gerbil test` command has
been observed to return exit status 0 even when it reports `ERROR HARNESS`.
The temporary build directory is intentionally left for inspection.

## Object scale

`object-scale-benchmark.ss` measures nine combinations of 8, 64, and 256
direct slots with prototype depths 1, 8, and 32. Each case performs 500 fresh
construction-and-first-read operations and 5,000 clones, both with and without
a first read. Fixture generation and warmup are outside the measured intervals.

On the local Gerbil `d801e7a` / Gambit `dcd677c` toolchain, three runs showed:

- Clone-only cost tracked direct slot width: about 0.011 seconds per 5,000
  clones at 8 slots, 0.021 at 64, and 0.053–0.071 at 256. Depth had much less
  effect on clone-only cost.
- Cold construction plus first read increased with both width and depth: roughly
  0.003–0.004 seconds per 500 objects at 8 slots/depth 1, versus 0.055–0.066
  at 256 slots/depth 32.
- Clone followed by first read also reflects instantiation work. It must not be
  described as the cost of `.cc` alone.

These measurements do not justify changing the object representation or adding
cache state. Revisit only if a real consumer has a documented clone/first-read
rate that makes this cost material.

## Tuple unmarshal: standard-library iteration

`Tuple. .unmarshal` previously used a local `vector-map-in-order` helper whose
per-element path called `apply` and mapped the remaining vector arguments.
The V19 `vector-unfold` constructor retains the same sequence-level expression
and consumes fields left to right; `vector-map/index` does not guarantee its
callback order and cannot be used for stateful port reads.

`t/tuple-unmarshal-performance-test.ss` checks a 256-field byte round trip and
measures 1,000 decodes per sample, five samples per run. The original medians
were 0.148 and 0.153 CPU seconds in the two baseline runs. The concise
`vector-unfold` implementation measured 0.138 and 0.134 seconds in two follow-up
runs, roughly 1.1× for this synthetic wide Tuple. An explicit
`vector-for-each/index` plus `vector-set!` was faster (0.122 and 0.120 seconds)
but lowered the abstraction level and added code, so it was not retained.
These are not general or cross-platform speed claims; ordinary Tuple semantics
remain covered by `t/type-test.ss`.

## Table count

`count-performance-benchmark.ss` measures RationalDict and Trie at 256,
4,096, and 16,384 entries, adjusting repetitions to visit roughly four million
entries per case. Fixtures and warmup are outside the measured intervals.
The benchmark also measures repeated updates to expose a possible cost of
maintaining cached sizes.

The initial Trie `.count` implementation recursively redispatched the POO
method for every child and took about 1.16–1.27 CPU seconds per case. A local
recursive algorithm in the benchmark took about 0.30–0.34 seconds. The final
implementation still obtains the overridable `.unwrap` prototype slot at the
method boundary, but resolves it once and recurses through a named local
function. It took about 0.18–0.21 seconds per case in follow-up runs. Existing
table tests and a dedicated persistent-trie regression test passed.

RationalDict `.count` remained about 0.04 seconds per case. The V19 RBTree and
the generic Table default both count by traversal; neither stores size. There
is no high-frequency production `.count` caller in this checkout, so adding a
size cache and write-side maintenance is not justified by current evidence.

## Iterator contract

`Set<-Table. .iter<-` distinguishes an omitted lower bound from an explicit
`from: 0`. RationalDict uses its native RBTree iterator for an unbounded scan;
an explicit bound filters the ordered entries inclusively. The contract test
covers negative keys, a fractional bound, an exact match, a bound beyond the
last key, direct dictionary iteration, and repeated EOF reads. This closes
the previously failing RationalSet lower-bound case without changing TrieSet's
POO interface.

## Wide-slot construction: storage-layer A/B

The original `.putslot!` and `.putdefault!` repeatedly search and append a
list, making wide incremental construction O(n²). The candidate keeps
`Class.proto` and its overridable `.slot.define` dispatch unchanged. Only
objects that receive a write open a private slot store: V19 symbolic HashTables
track values, and `:std/list/list-builder` materializes an ordered snapshot on
the next `object-slots` / `object-defaults` read. Prior snapshots, duplicate
input keys, and a custom descriptor's view of preceding definitions are tested.

```sh
bench_path=$(mktemp -d /tmp/poo-v19-class-proto.XXXXXX)
GERBIL_PATH="$bench_path" just build
GERBIL_PATH="$bench_path" just test
GERBIL_PATH="$bench_path" just benchmark-class-proto 10000 6
GERBIL_PATH="$bench_path" just benchmark-object-scale
```

On the local Gerbil `2591dcd` / Gambit `dcd677c` toolchain, the real 10,000-slot
`Class.proto` path measured 1.698 seconds median for the original code and
0.0897 seconds for this candidate (18.9×, six samples each). At 64 slots the
20-sample observations were approximately 0.43 ms versus 0.40 ms. One compiled
object-scale A/B kept clone-only and clone/read times within roughly 5% at 8,
64, and 256 slots; this single run is not a statistical or cross-platform gate.
`just test` passed. Raw struct-field reflection by external consumers still
needs qualification before calling the private-field change an ABI closure.
