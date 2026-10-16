# Automatic strongly connected component closure

This advances the generalized prototype future work in Appendix B, rather than
claiming SCC APIs already appear in its Racket implementation. The reference
`$lens-gen` compiles a complete component with a getter, setter, wrapper, cooked
self and raw parent. Here SCC discovery chooses which such equations must close
atomically; the existing lens compiler and feedback search perform construction.

## Composition

`strong-components.partition` consumes the existing immutable
`GeneralizedGraph.Declaration`: its explicit finite support and each Computation's
`reads`. It validates every reference, computes reflexive graph reachability and
partitions by mutual reachability. Members and representatives follow source
order. Isolated nodes, self loops, shared hubs and multi-node cycles are handled;
empty graphs still pass through joint approval. This is graph metadata analysis,
not inference of dependencies hidden inside Scheme closures.

`feedback-graph-action` is an ordinary FUN Reader from an old graph cache (or
`#f`) to an accepted graph cache. It freezes code/base identities, discovers SCCs,
condenses external reads to group representatives, and uses the existing checked
DAG scheduler, ConstructionCache and feedback-cache publication chain. A group
builder receives its full member list, frozen source, and a restricted provider
for declared external nodes. It must return an actual `close-feedback-group`
receipt, with whole-raw fixedness and EVERY component residual checked. Internal
reads use the preceding whole cooked self, external reads use closed predecessor
groups; cycles never see partially constructed cache slots.

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
are negative controls in `t/feedback-graph-test.ss`.

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
