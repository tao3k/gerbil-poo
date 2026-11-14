# Strongly connected component closure

An edge `invoice → tax` means that `invoice` declares a read of `tax`.
If both nodes can reach each other, they are in one strongly connected
component (SCC) and their equations run as a group. A read of `rate` in
another SCC uses that provider's completed value. SCC discovery chooses the
groups. The lens compiler and feedback search build the values.

## Composition

`partition` in [strong-components.ss](../strong-components.ss) reads the keys
and each Computation's declared `reads` from a `GeneralizedGraph.Declaration`.
It validates every reference and checks the resulting partition independently.
Members follow source order, and each group's first member is its representative.
Empty graphs still pass through joint approval. The graph contains declared
reads, so a dependency hidden in a Scheme closure must be declared explicitly.

`feedback-graph-action` is an ordinary FUN Reader from an old graph cache (or
`#f`) to an accepted graph cache. It freezes code/base identities, discovers SCCs,
condenses external reads to group representatives, and uses the existing checked
DAG scheduler, ConstructionCache and feedback-cache publication chain. A group
builder receives its full member list, frozen source, and a restricted provider
for declared external nodes. It must return an actual `close-feedback-group`
receipt, with whole-raw fixedness and EVERY component residual checked. Internal
reads use the preceding whole cooked self. External reads use the declared
target node and its closed provider group. [External read preparation](quotient-routes.org)

One group's recipe is retained only if its builder identity, ordered members,
member code/base identities, external footprint and dependency ownership match.
Merging or splitting dirties all affected new groups even if their values and
surviving representative are unchanged. Ordinary DAG invalidation then rebuilds
downstream readers. The construction cache now admits independent old slots
across support changes: a new slot always builds, a retained slot requires the
same code/base and clean declared predecessors. A removed dependency is rejected
by graph scheduling unless its consumer's footprint is also edited. Source
reordering may conservatively rebuild groups; this interface promises safe reuse,
not maximal reuse across arbitrary graph isomorphisms.

Registered fragment/lens sources of retained AND rebuilt groups remain guarded
through current joint approval. Policy-only changes skip all builders while still
running admission. Any graph error, missing input, nonconvergence, residual/lens
failure, stale source, builder failure or non-Boolean/negative approval retains
the exact old publication. Refused candidates never become a retry cache.

## Executable scenario

`examples/component-services.ss` uses a non-record vector carrier and native
functional lenses. A shared quota feeds left/right services; they initially form
a feedback pair. Settlement consumes both; an independent capped self-loop must
survive every shared revision. Removing right's read of left splits the pair;
restoring it merges the pair. Even equal resulting values require reconstruction
of changed groups and settlement. A fresh policy approves both commitments and
their settlement together. Source quota changes rebuild both services and
settlement but retain the independent group's exact object. Admission refusal,
retry, missing inputs, divergence, unsupported reads and FUN suffix suppression
are negative controls in `t/feedback/feedback-graph-test.ss`.

## Lean correspondence and evidence boundary

`Functional.StrongComponents` computes bounded reachability on finite keys and
checks reflexivity, edge inclusion and transitivity. Every accepted relation is
proved equivalent to unbounded finite-path reachability. Group membership is
therefore exactly mutual reachability; distinct groups cannot have paths both
ways. A separate universal theorem that discovery always accepts every finite
graph is NOT supplied. Native traversal computes visited reachability directly;
Lean certification is a semantic specification, not a verified extraction or a
proof of the Scheme compiler/runtime.

Proved revision laws cover membership-change seeds, added/removed-edge seeds,
transitive dirty readers, atomic dirtiness within an SCC and absence of any path
to a dirty seed for a retained node. Existing `FeedbackCache` / ConstructionCache
laws supply actual closed equations, conditional reference equality of clean
slots, builder skipping, and current final approval. `Examples/ComponentServices`
uses the same five equations, vector carrier, source revisions and explicit
budget; it runs actual lens feedback search plus every residual. Its fixture
supplies a dependency-first representative visit order; native condensation uses
the production DAG scheduler. `focus_laws` proves the custom vector lens laws on
ALL typed vectors; native checks remain finite operational controls.

Premises remain pure/locally total callbacks, correct declared reads, extensional
immutable metadata, lawful lens storage and a group builder that really closes
its specified member equations. No unconditional convergence, least fixed point,
cycle-interior skipping, arbitrary higher-order equality, allocation, GC or speed
claim follows. The example's budget is 32 raw transitions per rebuilt group;
partition traversal, residual checks, cooking and admission are additional work.
The native package is standalone and requires no Lean checkout or proof token.

Multiple simultaneous regroupings, shared-input migration and guarded batch
publication now compose through [service-revisions.md](service-revisions.md).

## Group discovery and paired costs

Discovery captures forward adjacency once. If every edge between distinct
nodes points in the same direction in source order, every SCC is a singleton.
Otherwise the compact path uses iterative Algorithm T; the wider representation
uses the existing iterative traversal. Both normalize results in source order.
The independent certificate checks every quotient edge. It retains reverse rows
only within nontrivial groups and uses reflexive singleton paths. Its spanning
walks and strict quotient ranks still reject invalid groups, in the original
per-owner refusal order. Transient discovery/normalization state is retired
before certification; public partition fields and identities stay unchanged.
The partition retains its existing owner/member hash indices; membership-change
comparison reads stored cardinalities and checks each old group once. See
[the measurement contract](construction-cache.org) for the proof boundary.

Run `just benchmark-scc` for the Graph study. The [benchmark report](graph-benchmark.org)
lists the 100,000- and 1,000,000-node workloads and separates source preparation,
SCC discovery, certification and graph updates.
All capacity observations check complete groups/counters outside the timers.
The existing 2-GiB heap and native TestSuite failure boundary remain.

`ComponentWitness` proves within-group paths and decreasing quotient ranks
suffice for exact SCC membership; equal finite cardinality plus indexed inclusion
suffices for unchanged groups. These are semantic contracts, not extraction or
a proof of Scheme compiler/hash-table/runtime complexity.

Signed allocation observations from the shared process-statistics helper are
retained as diagnostics. Negative values and collection-spanning samples do not
establish an allocation reduction; CPU/wall and GC controls remain separate.
A successful result marker alone is insufficient: the bounded process must exit
successfully, and the complete regression suite must also pass.

See [Graph algorithms](graph-algorithm-selection.org) for incremental repair
and publication.
