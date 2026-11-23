# Regional service configuration

Compose [base defaults, region settings, and tenant settings](service-configuration.ss).
The `.mix` order makes the tenant override win. The lazy request budget reads the
effective timeout and retry count from the composed object.

```sh
gerbil test examples/t/service-configuration
```

The European region supplies the endpoint and three retries. The tenant caps
each attempt at 250 ms, so the four attempts have a 1000 ms budget. The default
service still has a 3000 ms budget. [Runnable case](../t/service-configuration/service-configuration-test.ss)
