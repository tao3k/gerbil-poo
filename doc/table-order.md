# Explicit table order and range queries

This is a concrete extension of the proposed incremental/isomorphism-aware
collection library, not a claim that the original Racket construction already
specifies this API. Existing `methods.table`, typed Wrappers, correlated indexes
and FUN/IO styles remain the implementation boundary. Scheme has no dependency
on the companion Lean checkout.

## Protocol

- `table-comparer Key compare [dependencies]` binds a pure three-way procedure
  returning exactly -1, 0 or 1 to a key Type and metadata revisions. Use existing
  comparers such as `support/base`'s `number-comparer`.
- `table-comparer-wrapper comparer key-wrapper` requires the exact Domain Type
  and transports comparison by the Wrapper's inverse. Both encountered inverse
  laws and child membership are checked by the existing isomorphism validator.
- `table-order source comparer` requires identical key Types. It derives the
  standard table protocol from `methods.table` and delegates persistent carrier
  primitives to `source`. This rebinding matters: copying an instantiated source
  would leave its derived methods bound to the old traversal. Extensions beyond
  the table protocol are not copied; declare ordered index backends explicitly.
- `.seek state lower [inclusive?]` returns the first binding as `(some pair)`,
  or `#f` at EOF. It shares range admission and metadata failure semantics.
- `.range state lower upper [lower-inclusive? upper-inclusive?]` returns ordered
  `(key . value)` bindings. Bounds are `#f` (unbounded) or `(some key)`; `(some #f)`
  is a real bound when false belongs to the key Type. Inclusivity defaults true.
- `.index-range snapshot name lower upper [lower-inclusive? upper-inclusive?]`
  delegates to that declared backend's `.range`, retaining index ownership,
  freshness, unknown-name checks and callback guards. An unordered backend refuses.
  Grouped indexes return original primary-table buckets; unique indexes return
  primary owners. Private cache roots never escape.

Negative external keys can retain increasing *source* priority: transporting
numeric comparison through negation orders -10, -20, -30 in that sequence. Host
numeric order is never guessed. Values, including checked Functions, are merely
reordered with their keys. No row normalization occurs during comparison/query.

## Laws, invalidation and refusal

The explicit comparer must be pure, total and transitive, have reversed signs
when arguments are exchanged, and return zero exactly for equal keys. Backend
key equality must agree with `equal?`, as for existing correlated indexes. Runtime
checks reject non-sign results and encountered zero/equality disagreement; finite
checks cannot establish universal transitivity. A key Wrapper must be a genuine
isomorphism, with all mutable callback dependencies declared.

Malformed or ill-typed bounds refuse before enumeration. Reversed bounds refuse;
equal endpoints with either side open yield an empty interval. Callback exceptions
keep their original cause. Queries never publish partial lists or install state.
External callback effects cannot be rolled back. Supported mutations of active
metadata are guarded; cross-thread metadata revisions must be serialized as in
the existing collection protocol.

Comparer, key Wrapper, key Type and source revisions participate in origins. An
old ordered descriptor or retained indexed snapshot refuses after a dependency
changes. Reconstruct the comparer/view/index family explicitly. No hidden sort
cache can survive a revision. Deltas, multi-index uniqueness, inverse installation
and all pure/mutable/linear transitions retain their existing failure/ownership
semantics. Failed unique publication keeps the old owned capability usable;
repaired retry and inverse recovery restore the corresponding range observations.

## Positioned backends and validation reuse

A backend explicitly advertises `Comparer` and `.seek<- state lower inclusive?`
returning a Gerbil Iterator. Its laws require the exact lower-filtered enumeration
in its declared order, pure shape recognition and persistent, immutable-by-discipline
roots. `table-order` selects it only when Key identities and `.procedure` identities
match its explicit comparer. Constructor-owned weak revision seals also require
unchanged compare/procedure pairs; copied/overridden methods cannot borrow an old
procedure's capability. Equal-looking procedures are not assumed equivalent;
a mismatched comparer uses the reference sort/filter route.

Trie supplies this capability by reusing its standard `.iter<-` traversal. The
lower-bound path skips preceding branches and prefix-disjoint subtrees instead of
constructing a split table. `.range` stops at the first upper-bound failure.
`table-wrapper` transfers the capability through its existing typed key/value and
carrier isomorphisms. Boundary decoding uses the original inverse checks; each
iterator pull, including EOF, holds source guards. Use the derived `Comparer`
explicitly, so an xor-key representation follows source order rather than numeric
external order. Gerbil's public RBTree API in the installed release has no seek;
RationalDict retains the sorting route without reaching into private tree nodes.

For declared positioning backends, the standard weak-key table records successful
shape admission by root identity. Values are booleans and cannot retain the keys.
First admission still validates the whole structure; failed admission is never
cached. Metadata checks precede every cache lookup. Reclaimed cache entries may
require fresh admission. In-place structural mutation violates the persistent
backend premise and is not justified by this cache. Arbitrary backends without
the capability retain their original shape checking behavior. Admission does not
normalize rows or cache Function approvals.

## Cost and proof scope

After successful retained admission, Trie positioning takes a boundary spine and
range traversal visits the returned entries plus one boundary/EOF pull. Under
constant node operations its structural cost is O(h + m), with trie height h and
result size m; sparse large integers do not imply h = log n. First admission remains
O(n). Metadata, typed bounds, bignum operations, Wrapper inverses, source-specific
recognition and representation equality are additional costs. Wide/unbounded
queries still visit all returned rows. The fallback enumerates/sorts each query,
with O(n log n) comparisons under the host sort contract. No universal speedup or
runtime/GC proof is asserted.

`TableOrder.lean` formalizes comparer transport and interval observations, the
lawful backend window partition, equality of early stop with the full filter,
and the loop's exact output-length-plus-one pull count. Its total abstract work
bound explicitly assumes a height-bounded positioning cost certificate. These
laws do not verify Gerbil's coroutine, collector or concrete Trie implementation.
Backend-order, purity, persistence and interval-contiguity laws are explicit
premises; Scheme oracle regressions exercise the concrete implementation.

The existing `collection-paired-benchmark` additionally covers `order-cold`,
`order-seek`, `order-range` and `order-workflow`. Both sides share admitted inputs,
projection, indexes, ownership and inverse recovery. Only explicit capability
selection differs; the reference uses a separate but equivalent comparison
procedure. Cold includes new factories and index preparation. Workflow includes
difference discovery, linear installation, conversion, query and inverse. The
unchanged harness retains AB/BA, A/A, fixed prefix, natural/collected regimes,
wall/CPU/GC/allocation and history records. All original phases remain enabled.
Full observations go to stdout/local temporary logs, not versioned datasets.

## Local paired receipt

macOS arm64, Gerbil `1cfb032`, Gambit `ea114fc`; command
`just benchmark-collections 256 3 6` (256 UInt bindings, narrow four-row window,
three operations per observation, six AB/BA pairs, four A/A controls, prefix two).
All ten study phases completed. Values below are microseconds per operation;
wall columns are side medians, delta columns are medians of *paired* differences
(candidate minus reference). Non-GC CPU subtracts measured GC CPU from each sample.

| Phase | Regime | Reference wall | Positioned wall | Paired wall delta | Non-GC CPU delta | GC CPU delta |
|---|---|---:|---:|---:|---:|---:|
| Cold factory/index | natural | 64929.13 | 63781.70 | -1461.31 | -1137.17 | -287.00 |
| Cold factory/index | collected | 65512.18 | 64333.36 | -1037.48 | -680.83 | -286.67 |
| Seek | natural | 1125.06 | 5.84 | -1119.57 | -915.83 | -200.83 |
| Seek | collected | 1146.83 | 5.88 | -1140.16 | -927.67 | -201.50 |
| Range | natural | 1193.17 | 13.51 | -1179.66 | -933.50 | -230.17 |
| Range | collected | 911.20 | 13.47 | -897.21 | -896.83 | 0.00 |
| Workflow | natural | 8284.49 | 6123.82 | -2160.31 | -1851.83 | -305.33 |
| Workflow | collected | 8221.51 | 5817.49 | -2359.35 | -1860.50 | -454.67 |

Cold construction is **not qualified as a stable speedup**: it retains full shape
and index preparation, and collected A/A deltas span -1764.30 to -362.40 us,
overlapping its AB evidence. An earlier collected cold run had a +2431.00 us
median and a large positive outlier; it remains a local diagnostic, not a rewritten
pass. Source-origin preparation now deduplicates shared descriptors once using
`delete-duplicates/hash`. Collected workflow A/A also has a +5117.26 us outlier;
these finite observations do not establish a universal timing bound.

The independent structural regression uses 2048 bindings and four hits: after
explicit first admission, positioning unwraps 19 nodes versus the reference's
4095. Both return identical bindings; the counter has positive traversal controls.
First admission and failed-admission retry are tested separately. This work count
is not substituted for the wall/CPU/GC measurements above. Full pair/history data
remain in local logs; no generated dataset or archive is committed.

### Persistent update closure

`Trie.` declares `.shape-preserving?: #t`: for a valid persistent carrier and an
admitted Key, a successful `.acons` or `.remove` returns a valid carrier. This is
an explicit backend law, not a security certificate. Overrides must preserve it
or declare `#f`; arbitrary user backends are not inferred to satisfy it. Structural
mutation remains outside the persistent-root contract. Source versions are still
checked before using any admission, including constructor-produced roots.

`table-order` checks the initial input and update Key, delegates the update, and
records the output only after success under that law. It reuses Gerbil's weak-key
identity table with Boolean values; it does not retain intermediate roots, cache
exceptions, normalize Function leaves or cache contract approvals. Undeclared
backends keep full input checking. Metadata changes reject the view rather than
silently rebuilding its cache. Reclaimed entries can require fresh admission.

The controlled `checkedShapeUpdates_reuse` theorem equates repeated shape checks
with a once-admitted update chain under an explicit preservation premise, retaining
the original update error. `checkedShapeUpdates_valid` proves successful outputs
are admitted. `repeatedShapeWork_square` isolates the quadratic prefix-validation
term; actual point-update, weak-table, metadata, allocator and GC costs are not
removed by this algebra. The bounded-service example retains an opaque callback,
rejects capacity overflow and succeeds on a fresh repaired retry. These proofs do
not establish the preservation law for arbitrary Scheme code or its wall time.

### Cold preparation receipt (256 bindings)

Two complete local `just benchmark-collections 256 3 6` runs retained all twelve
phases, six AB/BA pairs, four reference A/A pairs and four candidate B/B pairs in
each natural/pre-collected regime. Both used the same Gerbil 1cfb032 / Gambit
ea114fc release on macOS arm64. The reference and candidate use the same positioned
comparer for factory/preparation/cold/workflow; only the explicit preservation law
is disabled in the reference. Query-only seek/range retain the sorting reference.
The immutable primary is built outside these timed factory actions; process startup
is recorded separately. No full observations are committed.

The instrumented prelude (outside timing) counts 256 projections on **both** paths.
Full shape recognition falls from 256 calls / 130,692 backend unfolds to one call /
one unfold. Total backend unfolds fall from 138,438 to 7,747: the removed work is
repeat recognition, not skipped index rows, callback validation or index assembly.
Regression checks also validate every intermediate sparse/80-bit-key output with
the raw recognizer, covering repeated insertions, missing removals and empty roots.

Second-run microseconds per operation (independent paired medians, not additive):

| Phase | Regime | Reference wall | Reused wall | Paired wall delta | Non-GC CPU delta | GC CPU delta |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| factory | natural | 351.15 | 166.14 | -188.83 | +1.50 | -190.17 |
| factory | collected | 161.69 | 161.17 | -1.51 | -1.17 | 0 |
| prepare | natural | 63,528.66 | 5,590.00 | -57,893.95 | -57,853.83 | -50.17 |
| prepare | collected | 63,275.81 | 5,366.64 | -57,820.52 | -57,712.33 | -31.17 |
| cold complete | natural | 64,288.14 | 5,931.66 | -58,346.99 | -58,131.50 | -23.50 |
| cold complete | collected | 64,841.67 | 6,011.53 | -58,793.51 | -58,496.17 | -58.17 |
| publication/undo | natural | 6,233.49 | 4,983.98 | -1,293.34 | -1,409.33 | +118.33 |
| publication/undo | collected | 7,983.53 | 6,914.18 | -2,373.85 | -1,484.50 | 0 |

Cold paired wall deltas remain negative in every sample: natural
[-58,951.38, -57,862.28], collected [-60,341.20, -58,100.62]. Candidate B/B ranges
are [-271.32, +207.03] and [-130.65, +59.29]; reference A/A retains the adverse
natural-history range [-12,542.01, +648.26]. The first run independently measured
cold medians 5,957.37 / 5,990.70 and paired savings 58,297.32 / 58,479.47.
Thus cold improvement is supported by both wall and non-GC CPU, not allocation
alone. Factory preparation itself has no qualified non-GC speedup.

Do **not** generalize this to stable publication latency: the second collected
workflow retains a +3,278.65 wall regression, reference A/A -6,475.37 and candidate
B/B +519.99; natural candidate B/B also reaches +2,044.60. Natural workflow GC CPU
regresses by 118.33 despite its favorable median wall delta. GC history and wall-only
outliers remain visible; no timeout, sample or failure was removed to qualify them.

## Shared change discovery in publication

`methods.table` now exposes `.for-each-change emit before after`. Its ordered
callback law is the existing `.diff` order: old updates/deletions in source order,
then new insertions in target order. `emit` receives Key, old Option and new Option.
The generic `table-for-each-change` implementation remains the independent complete
enumeration/lookup oracle. `.diff` still admits both inputs, guards all origins,
constructs the private delta and retains empty-delta dependencies. No child
recognition, Function wrapping, metadata approval or conflict check is cached away.

Trie specializes discovery using its existing pair and single-tree recursors.
An unchanged persistent subtree can be skipped by identity; one-sided subtrees
reuse the recursor's absolute prefix API. The generic three-argument `.foldl`
contract is unchanged, including lawful forwarding/instrumentation overrides.
Trie overrides must retain its declared ascending traversal law or override the
change protocol consistently. Other table implementations keep the generic path.
The helper is included from `trie/changes.scm` in the existing Trie module and is
registered through standard make `extra-inputs`; it creates no namespace or cache.

Reusing pair alignment exposed an existing common-prefix defect: changing a
singleton key 8 to 10 reported a deletion at 0 in the left cut child. Both children
now start at the common prefix. A finite independent oracle checks 128 sparse /
80-bit-key topology pairs; dense shared-subtree controls, stored false, failed
initial admission, exact callback error order, Function identity, unique-index
refusal, grouped migration and FUN consumer suppression/retry are also covered.
Complete admission is explicitly counted even for identical roots. In the 2,048
row / one-edit control, discovery alone drops from 61,438 backend unfolds to 56;
that count excludes the two required complete admissions.

The Lean `DeltaTraversal` certificate describes aligned shared/changed/ordered
regions. `prunedDelta_correct` proves the exact ordered edit list, so existing
installation and inverse operations retain their successes and original first
failure. `prunedDelta_work` preserves the fixed complete admission charge and
bounds only discovery visitor work. The alignment certificate, immutable-node
interpretation and agreement with the host equality/order are backend premises;
this does not verify concrete Gerbil node normalization, compiler, GC or wall time.

The original +3,278.65 us collected workflow pair had **zero interval collections
on both sides**, +2,304.67 us CPU delta and +973.99 us additional wall-minus-CPU
delta. This excludes an in-interval GC explanation, not effects of prior GC,
metadata preparation, cache state or clock/scheduling history. The signed residual
is recorded without assigning it automatically to operating-system waiting.

Revision benchmarks now compare the same shape-preserving indexed backend on both
sides and isolate generic versus shared discovery. Factory, cold preparation and
seek/range comparisons retain their previous controls. Additional `order-diff`,
`order-stage`, `order-owner` and `order-publication` phases separate discovery,
prepared-delta index installation, ownership conversion and fresh-factory complete
publication. The retained `order-workflow` still includes mutation construction,
discovery, admission, installation, range observation and inverse recovery.
Full publication additionally includes fresh descriptor/style and cache preparation;
primary rows and process startup remain separately recorded setup. All prior
phases, AB/BA, A/A, B/B and raw GC/allocation histories remain present.

### Paired publication receipt

The bounded macOS run uses `just benchmark-collections 256 3 6`, the compiled
Gerbil test runner, fresh fixtures, two prefix actions, six alternating AB/BA pairs
and four A/A plus four B/B pairs. All sixteen phases and semantic oracles pass.
Positive signed deltas below are regressions; numbers are microseconds per call.
No natural-history collection is forced. The added `post-gc` diagnostic, limited
to the five revision phases, records forced GC and the first following call
separately, then the ordinary batch. Its charged summary includes GC, first call
and the batch divided by the number of calls; this is not a runtime GC policy.

| Phase | Natural paired wall | Precollected paired wall | Precollected non-GC CPU |
| --- | ---: | ---: | ---: |
| Difference, including complete admission | -1,608.17 | -1,386.72 | -1,384.50 |
| Prepared-delta index installation | +8.19 | +5.01 | +2.67 |
| Ownership conversion | -3.18 | -0.64 | +1.17 |
| Retained-factory complete workflow | -1,423.16 | -1,330.53 | -1,330.67 |
| Fresh-factory complete publication | -1,316.11 | -1,475.02 | -1,457.50 |

Prepared installation and ownership bodies are identical between variants: these
phases are controls, not additional speedup claims. Fresh-factory publication has
reference/candidate medians 10,461.69 / 9,066.03 naturally and 10,620.83 / 9,140.01
precollected. Its charged post-GC paired median is -1,444.46. Forced-GC medians are
666.02 / 651.12; the following first complete calls are 10,173.44 / 8,661.51.
This observation does not reproduce a candidate-specific post-GC first-call penalty
or establish the cause of the historical outlier.

**Variation remains.** Natural publication A/A spans [-80.66, +75.02] and B/B
[-776.05, +5,698.36]; the latter's median is +1,344.05. Precollected A/A spans
[-200.99, +167.29], B/B [-58.65, +287.69]; charged post-GC B/B still spans
[+58.47, +308.99]. A preceding independent run also had favorable publication
paired medians (-3,126.34 / -2,679.71), but retained an adverse +1,664.40 AB pair
and B/B up to +5,232.02. Neither run is discarded. Discovery work and measured
median CPU improve; stable tail latency and a universal wall speedup are **not**
qualified. Allocations and interval GC history alone do not explain residuals.

The final single-process check passes all 128 modules / 1,249 cases within the
unchanged 300-second / 1-GiB bound (24.15 seconds measured test wall). No checks,
failed observations, resource limits or complete admissions were removed.

## Composable ordered cursors

`table-order` publishes `.seek<-` as well as `.seek` and `.range`. Its cursor is
an ordinary Gerbil `Iterator`, using the existing `iterator-map` guard mechanism.
A second order view with the same constructor-owned comparer delegates to that
cursor; a typed `table-wrapper` can transfer it again. Entries, including admitted
Function leaves, are passed through unchanged. Each layer checks its captured
sources on creation and on every deferred pull, including EOF. A failed check
precedes the underlying pull; no new entry or advanced tail is returned.

This capability states ordered enumeration, not logarithmic positioning. A
RationalDict fallback still sorts once per cursor creation through its public
operations. Composing an unchanged order view does not sort it again. A mismatched
or modified comparer retains the reference sort/filter route. Guard work grows
with the number of composed views; no universal constant-time, allocation or GC
bound follows. Persistent carrier and lawful comparer obligations are unchanged.

The nested service fixture combines transported xor keys, two order views,
correlated unique indexes, linear FUN publication, inverse recovery and conflict
retry. Regression controls prohibit full enumeration on a warm Trie path, preserve
opaque callback identity, reject invalid bounds and stale partially consumed or
exhausted cursors. Lean's `checkedTablePull` laws model revision refusal before a
single backend pull, exact payload/tail retention and nested-guard conjunction;
`tableRangePrefix_identity` preserves the existing finite prefix and pull count.
They do not verify Gerbil's coroutine implementation or user callback purity.

### Demand-driven bounded range cursors

`.range<- root lower upper [lower-inclusive? #t] [upper-inclusive? #t]` returns a
standard Gerbil Iterator over the same ordered bindings as `.range`. Lower/upper
are Options: false denotes an unbounded end, while some false can be a real typed
key. Malformed bounds, non-Boolean inclusion flags and reversed bounds refuse
during construction. Both Option shells are captured before child predicates or
comparisons run; logical key immutability remains a caller premise.

`table-order` reuses its declared seek cursor or its existing sort/filter fallback.
Gerbil `in-coroutine` owns suspended traversal and terminal EOF; no new iterator
class or scheduler is introduced. Each demand consumes one backend row until
EOF or the first upper-bound rejection. That boundary row is not returned. Further
EOF observations perform no backend pull, but still check current descriptor and
origin revisions. Comparator exceptions retain their original cause; corrected
retry constructs a fresh cursor over the retained persistent root.

The list-returning `.range` collects this same cursor. All five table/set styles
and Posh/Classy receivers expose `.range<-` through the existing deferred-observe
boundary; Set projects elements with the existing iterator mapper. Creating or
draining a cursor does not consume ownership. Later supported owner publication
does not rewrite its captured root; origin/descriptor invalidation refuses even
after EOF. Nested order views and explicit Wrapper transport reuse positioned
traversal; clients apply table-order to the transported seek capability.

`observe-ledger-range` uses the existing Reader/FUN/IO Observation to hand a
bounded stream to an application inspector. The inspector can stop early;
inspection failure suppresses consume, while already executed callback effects
are not rolled back. Regression controls cover seek/fallback correspondence,
all boundary flags, no-prefetch and sticky EOF pull counts, captured bound shells,
comparator failure/retry, nested origins, all styles/receivers, Function identity
and successful/refused service inspection.

Lean TableOrder reuses the existing finite range-prefix and ordered-window laws.
One demanded-step equation preserves the original prefix observation and exact
payload/tail, terminal observations cost zero backend pulls, rejection reads one
boundary row, and stale revisions refuse before any backend work including EOF.
Top-level service examples exercise bounded output, rejected boundaries and
current/stale terminal observations. Faithful ordered backend windows, metadata
admission, persistent roots and stable pure comparisons are premises, not proofs
of the Gerbil coroutine implementation, compiler or GC.

Design reflection: the absent bounded streaming capability is added to the
existing order protocol; eager range selection no longer has a parallel loop.
Standard coroutine/Iterator and existing guard/mapping abstractions supply the
mechanism. Seek retains its direct one-row observation rather than gaining a
redundant deferred wrapper. Fallback sorting still materializes the complete source;
initial recognition, positioning, metadata checks and boundary comparison are
charged separately. Partial consumption saves subsequent demands, not initial
fallback sorting or admission, and no wall-clock speedup is asserted. This is
finite collection-library future work, not automatic backend/order discovery.

### Deferred named-index observations

Indexed tables now expose `.index-iter<- state name`,
`.index-seek<- state name lower [inclusive? #t]` and
`.index-range<- state name lower upper [lower-inclusive? #t] [upper-inclusive? #t]`.
The first delegates ordinary backend iteration; the latter two require those
explicit ordered capabilities. Names, bounds, order and backend errors are not
guessed or coerced. Existing `.index-fold` is also available through every style
and receiver, alongside point lookup and materialized range observation.

One private with-index continuation now owns name resolution and family admission
for both old and new queries. Deferred results reuse iterator-map and the backend's
Iterator, with no cache copy, second sort or payload normalization. Unique indexes
yield admitted owner keys; grouped indexes yield their persistent source buckets.
The private complete index-cache root is not exposed.

Every delayed pull checks the complete owning family's revisions, including
primary and sibling declarations and inherited delta origins. The selected
backend retains its own order/comparer guard. These scopes are distinct: changing
an unrelated declaration invalidates a family cursor even when the selected
backend is unchanged. Terminal EOF never bypasses either required scope.
Supported publication creates a new immutable snapshot; a previously created
cursor retains the old root. Changing declarations requires fresh construction.

All five table styles and Posh/Classy receivers use the existing deferred-observe
boundary. Observation never consumes ownership. observe-indexed-range is a thin
named-query presentation of the existing bounded Reader/FUN/IO inspector; its
failure suppresses the consumer, with no rollback of prior callback effects.

Regressions compare lazy/eager ordered observations, unique/grouped outputs and
folds, retained Function identity, atomic priority swaps/shared-bucket migration,
inverse recovery, original snapshots, partial/terminal sibling invalidation,
unknown names, unsupported capabilities, foreign states, styles and service IO.
Lean TableOrder reuses ordinary range-pull semantics to establish family/backend
refusal before work, exact current forwarding and terminal zero backend pulls.
Named selection laws retain admission/lookup/backend failure order. Finite service
examples show unique/grouped observations and family-stale/selected-current EOF.
Faithful source stamps, persistent roots, ordered backend laws and pure metadata
callbacks are premises; compiler/GC and arbitrary external mutation are not proved.

Design reflection: this closes named-index traversal through the existing
collection observation chain, not a parallel query engine. Three repeated lookup
blocks were replaced by one continuation; the new cursor helper only delegates
and guards. Full family admission, metadata checks, positioning, fallback sorting
and selected-bucket traversal remain charged. Laziness avoids unrequested pulls;
it does not imply zero preparation cost or a wall-clock speedup. Automatic index
selection and backend/order discovery remain collection-library research work.

## Ordered whole-collection comparison

`(.call table .compare compare-values left right)` now shares one checked protocol
between the declared Trie structural capability and generic ordered Iterators.
An explicit `Comparer` is required; unordered tables still refuse instead of
acquiring a guessed host order. `table-order` and lawful key-Wrappers supply that
capability. Index families may be explicitly ordered in the same way. Both complete
roots are admitted before callbacks or empty/identical shortcuts.

The retained Trie convention is **union-key order with absence before presence**:
visit the union domain in the declared key order; at the first key present on only
one side, that side compares greater. At a common key call `compare-values` on its
two payloads and retain its first nonzero result. Equal common payloads continue;
two exhausted sources compare zero. This is not numerical entry-list sorting:
`{1: x}` compares greater than `{2: y}` in ascending key order because it is present
at the first union key. Reversing declared key order changes this decision.

The value callback must be a procedure returning an exact Integer. Its magnitude
is preserved; it may deliberately equate distinct payloads, including different
checked Function handles. Zero iff `equal?` is a **key comparer** law, not a
restriction imposed on value comparison. Unexpected callback/backend exceptions
retain their causes; non-Integer value results use the standard Gerbil contract
refusal. Key equality/order coherence, totality and transitivity/purity of supplied
orders remain declared laws, not properties inferred from arbitrary callbacks.

The generic path uses standard Iterator pulls and no merge result or snapshot
sort of its own. It captures each yielded Pair shell before another pull/callback,
uses explicit left-before-right evaluation, and stops without prefetch after the
first decision. The existing order view may still sort/materialize a backend that
lacks matching positioning. The Trie's original paired traversal remains under
`.compare/key`; it must satisfy the same declared order and presence laws. Derived
order/representation views inherit the generic protocol rather than borrowing
that raw structural capability without a law.

Set `.compare` uses the backing order with constant-zero Unit comparison. All five
Table/Set styles and Gerbil receivers expose nonconsuming comparison: Tables take
an explicit value comparator; Sets take the other owner. Each root is captured
once, sequentially, before user comparison. Reentrant publications remain visible
on owners while the comparison retains its two immutable observed snapshots. This
is not a joint atomic read across independently changing services. Consumed or
foreign owners and stale declared policies refuse through existing guards. Callback
effects are not rolled back; a fresh policy/factory can explicitly retry.

`compare-ledger-action` composes indexed service snapshots and explicit capacity
comparison through Reader/FUN/IO. Comparison failure suppresses the consumer;
Function leaves keep their exact admitted identity. Regressions include all 27×27
finite three-key Bool/presence pairs on structural and cursor paths, reverse and
transported order, full refinements, cursor demand/EOF, shared Pair shells, exact
large Integer results, every presentation/receiver and reentrant/revision retry.

The finite Lean `TableOrder` model proves reflexivity and reversal under explicit
callback laws, first-presence/value decisions, failure identity, representation
transport, complete admission precedence and a shorter-input bound on paired
steps. The existing `TableObservation` laws supply delegated, stale and consumed
owner behavior. Sorted faithful persistent enumeration and backend structural
comparison laws are premises. Admission, comparer validation, positioning/sorting,
conversion, allocation and GC remain charged; no logarithmic/constant total cost,
physical ownership, arbitrary callback termination or compiler/runtime proof is
claimed. This is a finite extension of the proposed collection library's future work.

Design reflection: one comparison boundary reuses the existing Trie algorithm,
order/comparer factories, Iterator interface and style snapshot reads. No merged
empty carrier, alternate tree/search engine, new namespace or Function-wrapper
layer is introduced. The existing presence convention is made explicit rather
than silently replaced by a different definition of lexicographic ordering.

## Standard rational backend order

`RationalDict` now advertises the order already supplied by Gerbil's
`std/struct/rbtree` Iterator. Its comparer explicitly uses numeric `=` for key
equivalence: `1` and `1.0` are distinct representations of one backend key.
`table-comparer` accepts `equal?:` and records `.equality` beside `.procedure`.
The equality result must be Boolean, zero must agree with it, and invalid signs
refuse before invoking equality. Key Wrappers transport the same relation. Other
comparers retain structural equality by default; membership alone cannot infer a
backend's key equivalence. Seek delegation requires both captured procedures to
match the source capability and both comparer seals to remain current.

The matching rational path does not materialize/sort `.list<-`. It reuses the
standard in-order Iterator, filters the lower prefix and lets the existing range
consumer stop at the upper boundary. Creation admits the complete persistent
snapshot once. Every emitted Pair is captured and typed, preserving Function
leaves; every pull, including repeated EOF, checks declared metadata. There is no
new tree traversal, cache or per-method wrapper family. Positioning remains linear,
and one boundary row can be pulled/checked beyond the returned range. Preparation,
row admission and metadata costs are not hidden inside a constant-time seek claim.

The existing `make-ordered-service-indexes` example accepts the primary and index
constructor. The same declarations now serve Trie or RationalDict owners/shared
buckets. Tests combine rational index ranges, unique swaps, group migration,
inverse recovery, and Wrapper/FUN/IO observations through all five styles; original
Function handles survive. Separate controls deny snapshot listing on the matching
path, retain sorting for mismatched equality, reject malformed roots/bounds and
refuse partially consumed/exhausted cursors after revision. Raw Table/Set compare
and split reuse the existing union-key/absence rules, including a present false.

Lean's `TableComparerLaws` permits an explicit key relation, with equivalence
premises kept separate. Projected/transported comparison laws preserve that relation;
tagged numeric representations illustrate zero without structural equality.
`tableLinearRange` agrees with the existing certified contiguous-window filter and
visits each backend row at most once. Its cost law separately charges preparation,
row visits, per-pull guards and per-row checks including a possible boundary row.
The law assumes a faithful ordered enumeration, lawful comparison and persistent
keys/rows. It does not verify the RBTree, floating-point primitives, compiler,
allocation/GC prices or elapsed time. No logarithmic seek is inferred from the
standard Iterator API, which exposes no lower-bound tree cursor.

The rational cursor also binds its producer to the actual numeric comparison and
equality procedures. Replacing the backend's advertised comparer without replacing
its producer refuses before pulling rows; use a separate `table-order` view for
an alternate order, which retains the legitimate reference sorting path.

Local complete acceptance for this unit: all 143 modules / 1,608 cases passed in
one process under the unchanged 1 GiB heap and 300-second runtime limits. All 20
Lean gate phases passed. This is bounded acceptance, not whole-library closure.


### Compiler resource acceptance

The first CI attempt exceeded the unchanged 1 GiB heap while std/make compiled
the old 27-root mixed collection group. Shared alist/boxed fixtures now live in
the existing `t/table-testing` support module, compiled once in the common artifact;
tests no longer import complete suite modules just to obtain a fixture. Collection
construction/validation, order, updates, styles and backend tests have independent
standard matrix groups with 7/4/6/4/6 roots. A regression caps these families while
the existing complete/disjoint inventory and include-freshness controls remain.
No scheduler, environment switch or expanded resource limit is added.

All five groups passed the actual `just build-group` entry locally under the
existing 1 GiB heap / 300-second stage limit. The final one-process suite also
passed all 143 modules / 1,608 cases. Compiler grouping does not replace or split
that runtime acceptance; Compile-group timing is not a wall-clock speedup
claim across different machines or cache histories.

### Request ownership before admission

Ordered queries capture their caller's Option shells before source recognition.
Table/Set style handoffs and named-index observations do the same before reading
snapshots or discovering computed query methods. `map/option identity` preserves
absent and malformed requests while copying only present outer cells; validation
still occurs in its original guarded order. Inclusive flags and opaque key leaves
are unchanged. A callback rewriting `[2,4]` into `[4,5]` cannot change the issued
query, and repairing an invalid caller cell cannot authorize that original request.

This costs at most two shallow cells per range handoff (one for seek), without a
new row traversal, sort, Function wrapper or cache. Existing preparation, source
admission and per-pull/EOF invalidation remain. Ordinary caller-side method lookup
precedes invocation and is outside this ownership boundary. Finite Lean proofs
cover endpoint capture and refusal ordering under stable key and faithful revision
premises; they do not establish arbitrary callback, compiler or GC correctness.
