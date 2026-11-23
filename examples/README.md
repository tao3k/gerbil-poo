# Examples

From the repository root, build once and run all the cases.

```sh
gerbil build
gerbil test examples
```

| Case | What it shows |
| --- | --- |
| [Service configuration](#override-a-service-timeout) | Layer a tenant override over a reusable prototype |
| [AI support triage](#triage-support-tickets-with-an-ai-provider) | Combine a typed provider boundary, knowledge lookup, a policy revision, and a human handoff |
| [Inspector pane](#extend-and-migrate-an-inspector-pane) | Extend a class from another module and dispatch on both class and render target |
| [Release control](#publish-and-revoke-a-release) | Resolve cyclic approvals, publish a callable policy, and retain the previous version on refusal |

## Override a service timeout

[Define the defaults and merge tenant settings](service-configuration.ss) with
`.o` and `.mix`. [Read the result](service-configuration-test.ss) with `.get`.

```sh
gerbil test examples/service-configuration-test.ss
```

The tenant gets a 250 ms timeout and inherits the endpoint and two retries.
The base timeout stays at 1000 ms.

## Triage support tickets with an AI provider

The [triage module](support-agent/triage.ss) validates the ticket, looks up
an approved article in a typed Table, and calls an injected provider through a
FUN Reader. The provider accepts the question and article text and returns JSON
with `draft`, `confidence` (0–100), and `review`. A structural contract checks
the decoded response. The [case](support-agent-test.ss) uses a recorded response
so it runs offline with no credentials.

```sh
gerbil test examples/support-agent-test.ss
```

A confidence of 91 produces a draft for review at the default threshold of 85.
Raising the threshold to 95 sends the same ticket to a person. The existing POO
dependency graph recomputes the decision and reuses the article and model
response. The delivery action checks the approved draft against the current run.
It refuses the old draft after a policy change and accepts a freshly reviewed
draft when the policy again allows it. Sensitive tickets and unknown articles
go to a person without calling the provider. An invalid provider response fails before producing a draft.

## Extend and migrate an Inspector pane

The [class module](pane/pane.ss) defines typed slots and an Inspector that
inherits from both Pane and Accessible. The [theme module](pane/theme.ss) adds
a `shared-initialize :after` method and its `theme:` initarg. The
[case](pane-test.ss) installs that bundle through the public MOP.

```sh
gerbil test examples/pane-test.ss
```

The caller creates a dark pane at width 120, reconfigures it to light and
migrates the same instance to InspectorPane. Terminal rendering combines the
class and `eql` specializers via `call-next-method` and an around method. It
keeps the width and adds the Inspector's section and inherited description.
The case reads the C4 precedence from the public MOP.

## Publish and revoke a release

In the [policy module](release-control/policy.ss), canary and stable approval
depend on each other. An operator approval seeds the cycle. A receiver-slot
generic combines Appendix B method fragments to return a production command
from an accepted snapshot. The [case](release-control-test.ss) exercises the
same command across promotion, refusal, and revocation.

```sh
gerbil test examples/release-control-test.ss
```

The release starts on hold. Approval and green checks allow a deploy decision.
Removing approval while requesting promotion refuses the candidate and retains
the exact prior version. Publishing the paused decision revokes the current
release. The case returns commands as data.

## Where to go next

The [documentation index](../doc/README.md) covers the API families and their
contracts. Use the [property testing guide](../doc/property-kernel.md) to check
invariants over many inputs. Regression suites and fixtures live in [`t/`](../t).
Performance workloads live in [`benchmarks/`](../benchmarks).
