# Kubernetes: starting footprint and cost

Checked October 16, 2026 (Pacific). **Budget: under $100/month for the new
platform alone.** The existing dev box and legacy Linodes are excluded, following
the updated budget instruction. This replaces the earlier all-hosting allowance.

**Recommendation:** UpCloud Managed Kubernetes in San Jose, one 4-CPU/16-GB
Starter worker, free Essentials networking/control plane, and temporary preview
and QA workers. Plan around **$63/month before tax**, or **$78 with a $15
tax/contingency reserve**, under the usage assumptions below. This is a public-rate
estimate, not an invoice or a measured deployment benchmark.

## Where resources run

Production apps, Argo CD, routing, metrics, logs, and initially a small database
share the production worker VM. UpCloud operates the control plane, external load
balancer, and NAT gateway. Preview and QA clusters use separate temporary worker
VMs; disruptive tests stay outside production and active previews. Builds run in
GitHub Actions. Keep backup objects outside the worker, preferably another region.

## Monthly model

| Item | Assumption | USD/month |
| --- | --- | ---: |
| Production worker | STARTER-4xCPU-16GB; bundled 50GB root disk | 32.00 |
| Control plane, shared LB, NAT | Explicit Essentials plans | 0.00 |
| Production persistent volumes | 50GB total Standard, separate from root | 4.85 |
| Backup object storage | First 250GB allocation | 5.00 |
| CI, registry, DNS allowance | Planning allowance; usage not yet measured | 5.00 |
| Preview + QA workers | 120 + 80 billed worker-hours at the same worker size | 9.52 |
| Temporary persistent volumes | 50GB per active worker, 200 hours total | 1.35 |
| Load generator | 2-CPU/4-GB Starter, 16 billed hours | 0.33 |
| Second production worker | 100 billed hours | 4.76 |
| **Modeled subtotal** | Before tax/contingency | **62.82** |
| Tax/contingency reserve | Allocation, not a tax-rate assertion | 15.00 |
| **Planning total** | Remaining room below $100: $22.18 | **77.82** |

Rates: [UpCloud USD pricing](https://upcloud.com/global/pricing/). Worker hours
use monthly price / 672 (28-day cap); storage uses monthly price / 720. Hourly
rounding and actual billing-month length can change small amounts. Worker-hours
include startup, teardown, extra nodes, and rolling-update overlap. Three previews
may share one worker if quotas allow; three workers consume three worker-hours
per elapsed hour. These hours are allocations to enforce, not forecasts.

The permanent baseline is $46.85 before temporary use. A second production worker
running all month raises the modeled subtotal to $90.05, or $105.05 with the
reserve. Sustained two-node operation therefore needs a revised budget or reduced
nonproduction use. High availability also costs more: the paid control plane,
production LB and HA NAT alone total $119/month before workers/storage.

## Conditions that make this price real

- Select `dev-md` control plane and `essentials` LB/NAT explicitly. These are
  ongoing free tiers, not trial credits. Account quota is five free LBs and five
  free NAT/VPN gateways combined. Capacity must still be available in San Jose.
  [Essentials](https://upcloud.com/docs/getting-started/upcloud-essentials/).
- Kubernetes currently defaults to a paid LB. Set the ingress Service annotation
  `service.beta.kubernetes.io/upcloud-load-balancer-config` to include
  `{"plan":"essentials"}`. [Documented default](https://upcloud.com/docs/guides/expose-services-upcloud-load-balancer-https/).
- Explicitly use `upcloud-block-storage-standard` for modeled PVCs. The root disk
  is already bundled; PVCs are extra. [CSI classes](https://upcloud.com/docs/products/managed-kubernetes/container-storage-interface/).
- Delete temporary workers, volumes and other billed resources. Stopping a Starter
  VM does not stop its charge. [Server billing](https://upcloud.com/docs/products/cloud-servers/configurations/).
- Free control plane, LB, NAT, and one worker provide no redundant platform.
  The free LB permits 1,000 concurrent sessions, not 1,000 users or requests/sec.
  [LB limits](https://upcloud.com/docs/products/managed-load-balancer/plans/).
- UpCloud lists network transfer at zero cost, subject to its Fair Transfer Policy;
  the model assumes UpCloud-hosted backups and no separately billed third-party
  transfer. [Transfer policy](https://upcloud.com/global/fair-transfer-policy/).
- Use the existing domain, short log/metric retention, and bounded database/object
  storage. No managed database, new domain registration, or per-app load balancer
  is included. CI charges depend on account-wide usage; the $5 allowance is not
  unlimited builds. [GitHub billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions).

Set alerts at $60/$80/$90, cap production at two workers, and refuse new optional
previews/tests when their forecast would exceed the monthly allowance. An external
cleanup job must expire environments and find orphaned resources. Alerts and node
limits are not a guaranteed dollar cap; preserve production and data if the budget
is threatened rather than automatically deleting them.

## Initial sizing, to verify before relying on it

Use a non-HA Argo CD installation, one gateway, automated certificates, one metrics
store, Grafana, and small single-process log storage. Keep builds outside the
cluster. Knative is optional until its incremental footprint is measured.
Argo's non-HA installation is documented for evaluation; using it for personal
hosting accepts downtime. This is not a redundant production deployment.
[Argo installation](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/).

Provisional RAM allocation: OS/Kubernetes 1.5GiB; Argo CD 1GiB; routing/TLS 0.5GiB;
metrics 1.5GiB; Grafana 0.75GiB; logs 1GiB; collectors/alerts 0.5GiB; database
1.5GiB; apps 2GiB. Total **10.25GiB**, leaving headroom on the 16GB plan. These
are planning envelopes, not measured idle usage or universal Helm defaults.
The 16GB worker costs only $8/month more than the 4-CPU/8-GB option.
Assume a handful of small apps, low traffic, modest metric cardinality, and less
than roughly 1GB/day of logs. Allocate the 50GB of PVCs initially as 20GB metrics,
20GB logs, and 10GB database; use seven-day metrics and three-day log retention
with disk alerts. Database backups, not duplicate metrics/log histories, use the
250GB object allocation. Render charts and disable large optional caches and HA
replicas; their defaults are not the budget above.
[Loki deployment](https://grafana.com/docs/loki/latest/setup/install/helm/install-monolithic/),
[Prometheus storage](https://prometheus.io/docs/prometheus/latest/storage/).

Before production use, measure idle and rollout RAM/CPU, allocatable resources,
disk growth, startup time, and loaded app latency. Verify HPA and worker scaling,
backup restore, and complete preview/QA deletion. Size requests and limits from
those results. Revisit CPU, storage I/O, and retention even if memory fits.
This needs a bounded temporary pilot charged against the QA allowance, followed
by teardown; the current read-only research has not run that pilot.

## Existing-host evidence, outside this budget

The live dev box reports 4 CPUs, about 8GB RAM, a 50GB root disk, and a 20GB data
disk. The user estimates its bill at $36/month and confirms assistant02 is running;
other legacy instances are unverified. Upstream configuration still selects
STARTER-4xCPU-8GB. Open PR #22's title says 8CPU/32GB, but its current diff actually
proposes 4CPU/16GB; neither change was applied here. No cloud billing credential
was available, so no actual invoice or full account inventory was verified.

No paid infrastructure was created and no production settings were changed.
