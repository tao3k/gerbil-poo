# Examples

Build Gerbil-POO once from the repository root, then run the case directories.

```sh
gerbil build
gerbil test examples/...
```

| Case | Application problem | POO features |
| --- | --- | --- |
| [Service configuration](service-configuration/README.md) | Apply region and tenant overrides while keeping the retry budget consistent | Prototype precedence, lazy slots, `.mix`, `.get` |
| [AI support triage](support-agent/README.md) | Keep reviewed answers current across policy and knowledge changes | Types, object contracts, FUN Reader, persistent Table, incremental DAG |
| [Inspector pane](pane/README.md) | Extend a live pane and handle typed events after switching its role | Class and Slot, C4, method bundles, multiple dispatch, instance migration |
| [Progressive release](release-control/README.md) | Promote only the reviewed and analyzed artifact and roll back to the stable build | Finite cyclic closure, publication, prototype methods, Appendix B combination |

Each directory contains its source, explanation, and runnable `*-test.ss`.
For deeper coverage see the [API index](../doc/README.md) and
[property testing guide](../doc/property-kernel.md).
Regression fixtures live in [`t/`](../t) and performance workloads in
[`benchmarks/`](../benchmarks).
