# Support triage with review and knowledge changes

A support team grounds draft replies in approved help articles. The
[triage module](triage.ss) validates incoming tickets and model JSON as POO
objects. A persistent Table stores approved article snapshots by ID and a FUN
Reader supplies the provider. Human review and delivery are separate steps.

```sh
gerbil test examples/t/support-agent
```

The [runnable cases](../t/support-agent/support-agent-test.ss) exercise these decisions.

- A draft scored 91 passes the default threshold of 85. Raising the threshold
  to 95 sends it to a human and invalidates the old draft for delivery. Restoring
  the threshold permits a fresh review, with one provider call across the run.
- Adding an unrelated article preserves the selected row and its decision.
  Correcting the selected article triggers a new proposal and review. The
  delivery callback receives the revised advice after approval.
- Sensitive requests and unknown articles bypass the provider. A provider can
  request review even at high confidence, and an out-of-range response fails
  before a draft is produced.

`refresh-knowledge` takes a new persistent catalogue whose unchanged rows
retain their identity. Pass the current triage run to `deliver-approved-draft`.
The cases inject recorded model data and a local delivery callback, so the
workflow runs offline.

The scenario adapts the retrieval and escalation workflow in the
[OpenAI customer support demo](https://github.com/openai/openai-support-agent-demo).
