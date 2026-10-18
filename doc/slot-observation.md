# Slot observations and cache replay

The MOP exports `call-with-slot-read-observer` and `replay-slot-reads!`.
`object.ss` owns read delivery across `.ref`, `.ref/cached`, `.ref/inline`,
presence queries and name enumeration. There is one value evaluator and one
cycle guard. No consumer needs to patch an object engine or inventory fields.

```scheme
(def records (make-hash-table-eq))
(def result
  (call-with-slot-read-observer
    (cut hash-put! records <> #t)
    (lambda () (.ref/inline configuration site))
    before: (lambda (receiver key) (check-selected-source receiver key))))
(replay-slot-reads! (hash-keys records) check-selected-source)
```

`check-selected-source` in this example is an application callback, not a POO
export. It may inspect source specifications without recursively observing its
own metadata accesses. Nested observers receive the same actual read tokens.
The `before:` callback runs before the selected getter; replay runs when the
consumer requests it, including immediately before admission returns. An
observer does not itself prove source identity or approve a configuration.

## Record and cache ownership

Each receiver owns its read table, cleared together with its normal cache and
layout. There is no global strong receiver registry. Cold computation captures
actual dependencies even outside an observer, so a value warmed before admission
can later replay them. Failed computations install neither a value nor a record.
A live token retains its receiver intentionally; releasing the receiver and all
consumer tokens leaves ordinary collectible cycles, not a registry root.

Value tokens bind the receiver, mutation revision, instance table, current cell
identity and dependency tokens. Supported edits invalidate them. Bootstrap
anchors bind their explicit constant value and revision without requiring an
instance table during self-hosted construction. Structure tokens retain their
first preparation dependencies, including reads made by MOP preparation hooks.
They enumerate names without demanding unselected field values.

Inline cache hits use the same delivery boundary as ordinary warm reads when a
computation or observer needs dependencies. An inactive hot inline read still
reads its guarded vector cell; it does not redirect through `.ref` or allocate a
new record. The access-site guard retains receiver, revision and layout identity.

A `.ref/cached` miss invokes the native default thunk without computing the slot.
It records **cache absence**, not field absence. Later cache population can make
that observation stale without changing the revision. Defaults have independent
observations because different invocations can depend on different inputs.
False values remain distinguishable from missing cache entries.

## Refusal and scope

Replay refuses a stale token with `stale slot dependency` and its key. It does
not rerun potentially effectful getters. Native prototype invalidation remains
unchanged; arbitrary dynamic cross-object reads are validated on replay rather
than silently recomputed. Caller synchronization of mutation/evaluation remains
a prerequisite. Raw struct/cache writes and mutation inside an already cached
container do not become supported revision events.

Source files, JSON origins, domain Contracts, selected contributions and final
plan identity remain application concerns. POO records accesses to their values;
it does not authenticate files, rewrite source provenance, or implement a Loader.
Eager `def-slots` extraction and closures over already-extracted scalars remain
ordinary lexical captures. They are not retroactively receiver-aware references.
