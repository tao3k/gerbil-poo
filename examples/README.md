# Examples

Build Gerbil-POO once from the repository root.

```sh
gerbil build
```

## Override a service timeout

[Define the defaults and merge tenant settings](service-configuration.ss) with
`.o` and `.mix`. [Read the result](service-configuration-test.ss) with `.get`.

```sh
gerbil test examples/service-configuration-test.ss
```

The tenant gets a 250 ms timeout and inherits the endpoint and two retries.
The base timeout stays at 1000 ms.

## Add a theme to a pane

[Define the pane](pane/pane.ss) and
[add its theme initializer in a separate module](pane/theme.ss).
[Install the method bundle and use the pane](pane-test.ss).

```sh
gerbil test examples/pane-test.ss
```

A pane starts with the `plain` decoration. Creating it with `theme: 'dark` sets
the decoration to `dark`. Reinitializing with `theme: 'light` changes it to
`light` and keeps the width at 120.

Regression suites and their fixtures live in [`t/`](../t).
Performance workloads and measurements live in [`benchmarks/`](../benchmarks).
