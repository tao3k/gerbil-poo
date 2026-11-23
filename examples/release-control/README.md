# Progressive release with revision-bound review

The [policy module](policy.ss) computes canary and stable readiness with
finite cyclic closure. An independent review seeds readiness for that build.
Appendix B method fragments publish a production command for the accepted
snapshot.

```sh
gerbil test examples/release-control
```

The [runnable case](release-control-test.ss) follows build 42 from review to
rollback.

- A release bot cannot approve its own build. An independent approval leaves
  the build on hold while the measurement is inconclusive.
- A passing measurement for build 42 waits for the release window before promotion. Build 43 must obtain
  its own review and measurement, even though both passed for build 42.
- A refused promotion returns the exact prior snapshot. A failed measurement
  publishes a rollback command from build 42 to the last stable build 41.

The command is data for a deployment executor. The approval rules draw on
GitHub deployment environments, and the measurement outcomes draw on Argo
Rollouts. [GitHub environment protection](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)
· [Argo Rollouts analysis](https://argo-rollouts.readthedocs.io/en/stable/features/analysis/)
