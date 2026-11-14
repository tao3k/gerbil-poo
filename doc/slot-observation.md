# Slot observations and cache replay

`call-with-slot-read-observer` reports reads made by `.ref`, `.ref/cached`,
`.ref/inline`, slot presence queries and name enumeration. Its optional
`before:` callback runs before the slot is demanded. Callbacks run with
observation disabled for their own reads. Nested observation scopes preserve
the order and identity of the records they receive.

```scheme
(import (only-in :clan/poo/object .o .get)
        (only-in :clan/poo/mop call-with-slot-read-observer replay-slot-reads!))

(def server (.o port: 8080))
(def reads '())
(def port
  (call-with-slot-read-observer
    (lambda (read) (set! reads (cons read reads)))
    (lambda () (.get server port))))
(replay-slot-reads! (reverse reads) (lambda (_receiver _key) (void)))
```

## Read records

Each receiver owns its read records alongside its value cache. A value record
identifies the receiver, slot, receiver revision, instance table, stored value
and ordered dependency records. Cold computation captures its dependencies
even without an observer. A failed computation installs neither a value nor a
read record. Structural reads can enumerate names without demanding their values.

A `.ref/cached` miss invokes the default thunk and records that the cell has no
cached value. Populating the cell can make that record stale without advancing
the receiver revision. A cached `#f` is a value.

Internal capture can deduplicate replay roots by record identity and keep the
first occurrence. Observers still receive every delivery in order. The
dependency lists attached to individual records retain their original order
and occurrences.

## Replay checks

1. Verify that POO issued every selected record and that its fields and
   dependency sequence match what was issued. The public `make-slot-read`
   constructor and `object-read-issuance` inspector grant no issuance.
2. Check the receiver revision and cached state for each record. For a read of
   `port`, this includes the saved read record and stored value for `port`.
   Before consulting those tables, check Gerbil's live `HashTable` accessors
   and the symbol-to-index table used by vector storage.
3. Deliver reads in depth-first preorder and check them again after callbacks.
   Replay reuses the original records and never reruns a getter. A stale read
   raises `stale slot dependency` with its key.

The retained traversal remembers the root order and dependency structure.
Every replay checks live validity again. During replay, supported edits whose
invalidation reaches a selected receiver fail before changing it. Nested
replay preserves the enclosing protection. Callers serialize mutation and
evaluation. Raw runtime writes and mutation within a cached value are outside
the revision protocol.

`reobserve-slot-reads!` uses the same checks for warm Type catalogs and delivers
the original records to the caller's capture. Source-file and application
admission checks remain the consumer's responsibility.

## Verification

The [Slot observation suite](../t/objects/object/slot-observation.ss) covers
observer order, prechecks, continuation reentry and independent thread scopes.
The [issued-read suite](../t/objects/issued-read-test.ss) checks forged and stale
records, replay protection and callback-time changes.

```sh
just test-file t/objects/object-test.ss
just test-file t/objects/issued-read-test.ss
```

Use the [read and replay benchmark commands](performance/read-replay.org)
for the fixed-field and replay studies.

[LeanPoo observation scopes](https://github.com/tao3k/lean-poo/blob/40ee367b5195aa56d73fe9c9eda3666c88348c45/LeanPoo/Object/SlotObservation.lean#L34) ·
[LeanPoo read fields and issuance](https://github.com/tao3k/lean-poo/blob/40ee367b5195aa56d73fe9c9eda3666c88348c45/LeanPoo/Object/FixedFieldLayout.lean#L42-L95) ·
[LeanPoo replay check equivalence](https://github.com/tao3k/lean-poo/blob/40ee367b5195aa56d73fe9c9eda3666c88348c45/LeanPoo/Object/ReadRouteSharing.lean#L143-L149)
