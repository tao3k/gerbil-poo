# Examples

Run these commands from the repository root with the same Gerbil environment.

```sh
gerbil build
gerbil -:max-heap=2G,debug=q test -v 5 examples/service-configuration-test.ss examples/pane-test.ss
```

## Override one service setting

[Service configuration](service-configuration.ss) uses `.o` to declare defaults
and `.mix` to layer tenant settings. [The consumer](service-configuration-test.ss)
uses `.get` to read the composed configuration. It gets a 250 ms timeout, inherits
`https://api.example.org` and two retries, and sees 1000 ms on the base object.

## Extend a pane from another module

[Pane](pane/pane.ss) declares the width and decoration slots. The independent
[theme module](pane/theme.ss) contributes a `shared-initialize` method that
handles the `theme:` keyword. [The application](pane-test.ss) installs the
method bundle when it wants the extension. A pane starts with the plain decoration.
Creating a pane at width 120 with the dark theme yields `dark`. Reinitializing
the same pane with the light theme yields `light` and keeps width 120.

Both cases report `CASE-OK`, followed by `HARNESS-OK` and `OK`.
