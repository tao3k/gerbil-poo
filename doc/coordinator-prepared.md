# Prepared recovery and competing publication

This is generalized-prototype future work beyond the original Racket construction.
The existing lens guards, whole graph revisions and FUN/IO service operations remain
the semantic building blocks.

`rejoin-checked prepare validate continue` preserves all preparation results, then
calls `validate exchange ...` before the continuation. Validation can rendezvous
with peers after preparation succeeds. Raising a refusal preserves its identity
and uses ordinary named recovery; only an explicit fresh operation retries.

`joint-publication.check-approved owner receipt` returns `(values current failure)`.
It checks the opaque receipt's owner, exact expected snapshot and registered guards
under the same short lock as installation. It performs no rebuilding, binding,
approval callback or owner write. A successful observation is not a reservation:
installation rechecks everything and can still lose to another publisher.

`t/coordinator-prepared-test.ss` covers six component merge/delete/split/restore
rounds, two recovering names, both release orders, publication while prepared,
same-value shared approval invalidation, explicit retries, two-way installation
and historical receipt refusal. All handshakes are bounded; no sleep chooses a winner.

The companion model proves stale continuation exclusion, exact receipt preservation
on fresh checks, and refusal if another change occurs after observation. Its scope
is finite traces of atomic checked installation, fresh head identities, registered
guards and pure/locally total callbacks. It does not prove process-crash recovery,
fair scheduling, eventual success or the Gerbil memory model. This project
runs independently; the companion checkout is not a build/test dependency.
