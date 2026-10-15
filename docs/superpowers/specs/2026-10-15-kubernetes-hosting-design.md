# Kubernetes hosting: environments, promotion, testing, and cost

Date: 2026-10-15 (America/Los_Angeles)
Status: proposed design; no infrastructure provisioned or deployment authorized by this document.

## Intent and agreed constraints

Build a small hosting platform for the outliner and other applications, with an
app/domain inventory, resource visibility, repeatable deployment, horizontal
scaling, and scale-to-zero for suitable workloads. Learning Kubernetes is part
of the goal. Kubernetes is the user's working direction; the distribution and
provider have not been selected finally.

Ephemeral per-PR application previews are also required, with URLs for inspecting
changes before merge. Kubernetes supplies isolation/scheduling primitives; the
preview lifecycle, routing, data, and cleanup must be implemented explicitly.

The total hosting budget, including the existing dev box, is at most roughly
USD 100–150/month, preferably substantially less. QA/staging may be created on
demand and torn down afterward. Applications AND infrastructure changes must
be testable before production. Load tests are a first-class requirement.

The user has not yet accepted production downtime or selected recovery targets.
Initial single-worker production is a costed option, not an availability promise.

## Recommendation and alternatives

Evaluate UpCloud managed Kubernetes with its free, non-HA Development control
plane as the initial substrate. Keep self-managed k3s as the alternative if
provider limitations, full costs, or the desired cluster-administration learning
experience favor it. Use the SAME provider, Kubernetes distribution, and relevant
network/storage integrations in QA and production. Local kind/k3d checks are
useful early checks but cannot qualify cloud infrastructure changes.

Do not revive the old k3s PR unchanged. Preserve the existing dev box while the
platform is validated. Infrastructure provisioning remains OpenTofu/Terramate;
Flux reconciles Kubernetes resources. Use Headlamp as the initial cluster UI and
Prometheus/Grafana for resource and application metrics. Verify that the resulting
app inventory exposes domains and release versions without requiring the owner
to navigate raw Kubernetes objects for routine work.

Knative Serving is the proposed request-driven app autoscaler. Cluster Autoscaler
is the proposed worker-capacity controller for managed Kubernetes. A k3s choice
requires an explicit, tested node-provisioning integration; Kubernetes alone does
not create cloud servers. Introduce KEDA only when queue workers need it.

## Environment model

| Environment | Lifetime | Purpose | Isolation |
| --- | --- | --- | --- |
| Local / dev box | Existing development lifecycle | Editing, builds, unit tests, local integration | No production runtime dependency |
| Production | Persistent | Real app traffic and durable data | Own cluster, network, state, identities, secrets, domains, volumes |
| Preview pool | On demand while preview leases are active | Host lightweight per-PR app previews | Separate non-production cluster; namespace, quota, data, and route per preview |
| QA / staging | One disposable cluster per test run; initially serialize runs | Release acceptance, infrastructure rehearsals, load and recovery tests | Own control plane and workers; no production data-store or credentials |
| Load generator | Bounded test job or temporary VM | Generate calibrated traffic against QA | Outside target workers; cannot contend with the measured application |

Production, the preview pool, and infrastructure/performance QA are distinct
cluster roles. The preview pool is only provisioned when requested; it is not a
third permanent bill. Production and QA MUST be separate clusters. Namespace
isolation cannot protect
production from shared control-plane, CNI, CSI, ingress-controller, CRD, or node
changes. Namespaces are useful WITHIN the preview pool for app previews, with
quotas and policies. Initially allow only one QA run at a time to keep costs and
attribution simple. Keep disruptive platform changes and sustained load tests
off the preview pool so they do not invalidate another app's review session.

Each QA run has a run ID, owner, source revisions, creation time, expiration time,
resource inventory, test report location, and cost allowance. QA has its own data
and fixture lifecycle. Use synthetic fixtures by default; any sanitized data
import is an explicit operation with no production credentials passed to QA.
External mail, payments, webhooks, and agent actions use sandbox endpoints or stubs.

Budget-friendly QA can be smaller for functional tests. Capacity claims require
production-equivalent node types, resource settings, replica topology, storage,
ingress, and autoscaler behavior for the duration of the test. Record all differences;
do not extrapolate a tiny single-worker QA result into a production capacity claim.

## Per-PR application previews

An app PR produces an immutable image digest. After trusted-workflow checks,
an authorized preview request creates or updates a release in a namespace such
as `preview-<app>-pr-<number>`. The preview is pinned to the PR head digest;
subsequent commits supersede the old preview only after the new image is ready.
Show the URL, exact commit, readiness, and expiration on the PR and dashboard.
Example URL: `pr-42-<app>.preview.matz.io`, covered by a single-level wildcard.

The preview pool follows the current qualified platform release; application
previews cannot install cluster-scoped resources or arbitrary Helm hooks.
Platform PRs use isolated QA. A preview namespace receives resource quotas,
limits, a dedicated service account, network isolation, and disposable data.
Allow controlled ingress and required dependencies; deny access to production,
other previews, cloud metadata/credential endpoints, and cluster administration.
Use Pod Security restrictions, with no privileged pods, host mounts, Docker
socket, or production credentials. Reject previews that cannot meet this model.
Untrusted contributions require review before execution; a privileged workflow
must not check out and execute untrusted PR scripts with deployment credentials.

Static apps get a preview route with no database. Stateful apps declare dependency
templates and fixtures: e.g. a disposable database or scoped database/schema with
separate credentials, selected to meet the app's isolation requirements. Shared
database schemas alone are not adequate when tests modify cluster-wide/database
global behavior. No preview points at a production backend. Destructive migrations
are exercised on disposable data; compatibility qualification still occurs in QA.

Proposed cost controls: previews are requested with an authorized PR label/button,
not created automatically for every open PR; start with at most three active
lightweight previews and one preview-pool worker. Use a four-hour lease; each
explicit renewal extends expiry by up to four hours from the renewal time.
Quota admission can reject or
queue a preview even below the count limit when its dependencies do not fit.
App sleep/wake can reduce idle usage, but expiration is required even for sleeping
apps. Closing/merging the PR or lease expiry removes its route, workload, secrets,
and disposable data. Destroy the preview pool when its last lease is gone, after
checking for in-flight creation/update operations. Its controller/janitor runs
outside the pool and reconciles Git desired state before deleting cloud resources,
so Flux cannot recreate an expired preview.

A preview demonstrates the PR in isolation; it does not replace QA qualification,
performance testing, or promotion of the tested release. Store preview diagnostics
outside the pool as needed. Preview health does not certify production readiness.

Proposed platform-update policy: pin an occupied preview pool to its original
qualified platform release. When a newer release is selected, stop admitting new
previews to that pool and set a maintenance deadline no later than 24 hours away.
Existing leases and renewals cannot exceed that deadline; display it alongside
the preview expiry. Drain leases, destroy the pool, then recreate it at the new
release on demand. Queue new requests during the drain. Do not provision a second
pool or upgrade an occupied pool implicitly. Security emergencies may require
earlier explicit revocation with a visible reason.

## Ownership and isolation boundaries

* Separate OpenTofu stacks and backend keys for production, the preview pool,
  and each QA run.
  QA destruction must never traverse production state or shared root DNS/state
  infrastructure. State locking and serialized environment applies are required.
* Separate deploy identities and secret-decryption scopes for QA and production.
  Prefer provider-enforced project/subaccount boundaries. Before implementation,
  verify the actual UpCloud token scopes available; separate state files alone are
  not a credential boundary. If tokens cannot be narrowed sufficiently, use an
  isolated account/subaccount or document the remaining risk for owner decision.
* Separate DNS subzones/record scopes, certificates, storage prefixes/volumes, and
  database instances. Example naming: production `<app>.app.matz.io`; QA
  `<app>.<run-id>.qa.matz.io`, subject to DNS delegation and certificate validation.
  A single-level wildcard does not cover every nested QA hostname.
* Shared foundations (parent DNS delegation, state backend, identity policies)
  have a distinct workflow. Test equivalent changes in a disposable delegated
  zone/backend/identity scope; review the production-specific diff separately.
  Some global/provider changes cannot be fully rehearsed and must say so.
* App and QA workflows cannot invoke production apply or read production secrets.
  Untrusted pull-request code receives no provisioning credentials.

## Release identity and promotion

Use one Git repository with environment-specific roots and immutable release
inputs. Do not have production and QA both import a mutable shared base from
`main`: that would allow a QA change to modify production before promotion.

Suggested logical layout (names may be refined by the implementer):

```
stacks/platform-foundation/
stacks/platform-production/
stacks/platform-previews/
stacks/platform-qa/<run-id>/
clusters/production/              # pinned platform and application releases
clusters/previews/                # qualified platform pin; leased PR releases
clusters/qa/<run-id>/             # candidate pins and run-specific overlays
platform/                        # source for versioned platform bundles
apps/<app>/                      # app deployment definitions and test contracts
```

Produce a release record containing application image digests, platform bundle
digest or Git SHA, infrastructure module revision, provider lockfiles, Kubernetes
version, environment overlay hash, test-suite revision, and fixtures version.
Platform bundles and shared modules must be versioned/pinned independently of
the environment pointer. Flux must reconcile the promoted digest/revision, not
whatever happens to be the latest shared files.

Build each app image once. Deploy that digest to QA and promote the same digest
to production. Do not rebuild from a branch/tag at promotion time. Production
secrets and environment-specific values remain separate, with differences checked.

Proposed initial qualification policy: bind QA evidence to the complete baseline
production release record plus the candidate change, including all deployed app
digests and platform inputs. Serialize promotions and recheck that baseline before
applying. Any intervening production release or material configuration drift makes
the evidence stale and requires qualification against the new baseline. Record
environment differences explicitly; normal traffic and runtime replica counts
are not release changes. This conservative policy suits a small app portfolio;
dependency-scoped qualification can be introduced later with explicit contracts.

### Application release path

1. PR: unit/integration tests, build, dependency and manifest validation.
2. On an explicit authorized release request, provision QA at the known-good
   platform release and deploy the candidate image. Routine PR updates and preview
   requests do not automatically create a QA cluster. Queue release requests;
   superseding a queued candidate cancels its old request, while canceling a running
   candidate must still export evidence and complete cleanup.
3. Run readiness, browser/API, migration, and relevant regression tests; load-test
   when the change or release requires it. Store reports outside disposable QA.
4. Create a production promotion PR recording the tested image and evidence.
   Initially the owner merges production promotion PRs; QA success does not
   directly modify production.
5. Deploy, smoke-test, and monitor against the previous release. Revert the image
   or configuration when safe. Treat schema/data recovery separately.

### Infrastructure / platform release path

1. Validate modules, lockfiles, rendered manifests, policies, and cost impact.
2. Create QA using the CURRENT production platform release. Establish a passing
   baseline and test data, then apply the candidate upgrade to this existing QA.
   A fresh install of the candidate is not evidence that an upgrade is safe.
3. Exercise the affected behaviors: ingress/TLS, DNS, network policy, persistent
   storage, controller reconciliation, node drains, restart/replacement, upgrades,
   autoscaling, and backup restore. Also test fresh bootstrap/recreation.
4. Promote the tested source/module/platform versions to the production roots.
   Generate a fresh PRODUCTION plan using production state; never reuse a QA
   plan. Review replacements, resizes, deletions, and IAM/DNS changes explicitly.
5. Apply the protected saved production plan for the exact reviewed revision.
   Expire/replan when state, inputs, code, or dependencies change. Treat plan
   artifacts as sensitive. Serialize production applies and verify convergence.

Promotion is a logical transaction, not a promise that all cloud resources can
change atomically. The implementation must define operation order and stop points.
Database migrations use expand/contract compatibility when feasible. Kubernetes
version downgrades and persistent-volume changes may not be reversible; define
forward-fix or replacement-and-restore procedures for each before promotion.

The current repo automatically applies changed stacks on main, and comin tracks
main for the dev box. That is insufficient as the new production promotion model.
Scope each environment explicitly; a QA/docs merge must not reconcile unrelated
production capacity. The prior accidental dev-box resize is a concrete regression
case. Dev-box changes themselves require a temporary NixOS VM rehearsal when they
affect boot, storage, networking, or service behavior; a Kubernetes QA cluster
does not validate NixOS host changes. Include that temporary VM in test costs.

## QA lifecycle and cleanup

Default proposal: a four-hour QA lease, explicitly renewable, with one active run.
Create -> bootstrap -> seed -> baseline -> candidate -> test -> export evidence
-> destroy. Readiness checks determine when QA is usable; do not promise a fixed
startup time before measuring provider provisioning and bootstrap.

Use workflow cleanup AND a scheduled janitor running outside QA. A canceled
workflow or failed cluster must not prevent cleanup. The janitor only targets
expired resources with matching QA ownership labels and registry entries; it has
no production deletion authority. Record and alert on cleanup failures.

Use externally hosted CI workflows for provisioning and scheduled reconciliation,
with a durable lease/resource registry outside disposable clusters. Serialize
create, renew, update, and destroy operations per environment; record an intended
operation before provisioning so partial failures remain discoverable. Reconcile
provider inventory against the registry, including partially created resources.
The exact registry implementation is a builder choice; an in-cluster-only timer
or CI job's local filesystem is insufficient.

Delete the complete QA cluster and its disposable workers, load balancers,
addresses, volumes, and test data when finished. Do not assume a running cluster
can scale every worker to zero. Retained reports/backups have explicit lifetimes
and count toward cost. Verify provider inventory after destruction, not just
that the workflow exited successfully. A failed run retains reports by default,
not an indefinitely running cluster.

## Load tests and acceptance evidence

Use versioned k6 scenarios and thresholds. The load generator targets only the
run's verified QA hostname; destructive or sustained production tests are outside
the normal pipeline. Cap duration, concurrency/request rate, and maximum workers.

| Test | Evidence required |
| --- | --- |
| Steady baseline and peak | Throughput, p50/p95/p99 latency, failures, CPU/RAM, dependency saturation |
| Spike and sustained load | Queueing, throttling, recovery, generator saturation, worker provisioning delay |
| App sleep/wake | Zero replicas after idle; first request completion, cold-start latency, concurrent wake requests |
| Horizontal scaling | Replica increase, actual work distribution, new worker creation when required, scale-down |
| Node drain/failure | Rescheduling, connection behavior, data availability, recovery time |
| Release under traffic | Error/latency behavior during rollout, readiness/draining, safe rollback |
| Stateful recovery | Restore to isolated storage, integrity checks, measured recovery time and data loss window |

Each app supplies its workload model, expected traffic, warm and cold latency
targets, allowable error rate, state model, and external dependency limits.
The implementer may set illustrative thresholds for a synthetic demo, but cannot
claim production capacity without app-specific targets. Threshold failures must
fail qualification. Record test topology, release identities, generator config,
raw metrics, report, and cost estimate together.

The current outliner is a static frontend with browser-local data. A static file
load test validates delivery only; it cannot validate a future sync backend or
cross-device data integrity. Use a small synthetic HTTP service to prove sleeping,
replica scaling, and worker expansion. Validate actual apps separately. WebSocket
workloads need their own concurrency, draining, and reconnect tests.

## Dashboard and operations contract

Show environment identity prominently. Inventory each app's domains, deployment
digest, readiness, desired/actual replicas, scaling limits, CPU/RAM requests and
usage, recent errors, and links to logs, metrics, and promotion history. Show
cluster capacity, pending workloads, failed reconciliations, and node health.
QA views must show expiration and the owning test run. Distinguish unavailable QA
from failed production. A dashboard disconnected from a cluster must not show
cached green status as current health.

Start with existing UIs and a consistent app label/annotation convention; a custom
portal is not initially required. Keep admin interfaces private. Use an external
uptime check and an alert path that survives loss of the production worker. Limit
metrics/log retention initially (proposal: seven days); archive release evidence
separately (proposal: 30 days). Infrastructure and app backups have workload-specific
retention, not automatically the log-retention policy.

## Cost model and capacity policy

All numbers below are USD BUDGET ALLOCATIONS, not provider quotes or a verified
bill. Verify account currency, region/SKUs, tax, quotas, retained storage, existing
Linode services, and other recurring hosting before committing spend.

| Bucket | Proposed monthly allocation |
| --- | ---: |
| Existing dev box, including its storage/backups | 35 |
| Production worker baseline | 25 |
| App storage/backups/DNS and other baseline overhead | 15 |
| Previews, QA, external load generation, temporary host rehearsals | 10 |
| Ordinary burst capacity | 15 |
| Normal target | 100 |
| Remaining margin below absolute planning ceiling | 50 |

Aim for idle usage closer to USD 60–80 if verified costs permit. The USD 150
ceiling includes all hosting, not just Kubernetes. Unretired legacy bills reduce
the available allocations; do not silently exclude them. Upgrading the dev box
also consumes this same envelope. This design does not promise HA within it.

Calculate test cost from actual rounded provider-billed resource-hours, storage,
snapshots, addresses, and report retention. For intuition ONLY: a resource quoted
at USD 25 per 720 hours costs about USD 0.035/hour, so 40 aggregate resource-hours
would be about USD 1.39. Real billing caps/rounding and resource types differ; use
the provider's hourly rates, not this illustrative conversion, in enforcement.

Before each run, estimate its maximum permitted duration and topology against
remaining test allowance. Forecast the month using current spend plus baseline
and maximum sustained autoscaler settings. Start with production min=1/max=2
workers, QA max=2, and preview-pool max=1 as proposed limits; recalculate against
verified pricing. At most one QA run plus the preview pool may coexist, with no
more than three non-production workers total. Admission includes the cost of
existing preview leases; queue optional QA when the remaining allowance is too
small. Both non-production roles are disposable, but do not evict an unexpired
preview silently to make room for a test.
Any necessary test topology above that is a separate bounded run allowance.

Node and replica limits constrain capacity, not the total invoice. Storage growth,
other services, taxes, and retained resources need separate controls. Budget alerts
are notifications, not a hard spending cap. Stop admitting optional tests/burst
increases when the forecast exceeds the agreed envelope; never automatically
delete production data or stop production merely because a cost alert fires.

Keep Terraform's desired node count from fighting the node autoscaler. Test
provider-specific scale-up/down behavior and set every node group's bounds
explicitly. UpCloud's overview and detailed guide differ on zero-sized node-group
behavior; do not rely on zero-node groups without a verified experiment. Destroy
on-demand QA instead. App scale-to-zero saves shared compute capacity but only
reduces VM charges when actual workers can be removed.

## Delivery and decisions still required

1. Reconcile the bill/resource inventory; verify provider capabilities and produce
   a complete costed topology. Select managed Kubernetes or k3s on that evidence.
   Measure controller/UI/observability overhead on the proposed smallest worker;
   do not assume the complete stack fits its budget allocation. Qualify private
   admin and CI connectivity, including Tailscale/CNI/load-balancer CIDR conflicts,
   ingress compatibility with Knative, and scoped provisioning credentials.
2. Build disposable QA and promotion isolation first. Prove clean creation,
   teardown, expiry cleanup, and the infrastructure upgrade/recreation path.
3. Add dashboard/metrics, domains, image deployment, and per-PR preview lifecycle;
   verify update, close/merge/expiry, isolation, and last-preview pool teardown.
   Add external load testing against isolated QA.
4. Prove app zero-to-many and worker expansion/contraction under bounded load.
5. Qualify the first application, recover its backups where applicable, and create
   production only after its availability/recovery policy and costs are accepted.

User decision remaining: initial production availability and acceptable recovery
time/data loss. The low-cost option has a non-HA control plane and one baseline
worker. More workers alone do not remove control-plane, ingress, or database
single points of failure. Present the priced alternative before asking the owner
to accept a particular availability level. These decisions do not block modeling
or building a later-authorized disposable QA experiment.

Implementation choices left to the builder: supported pinned component versions,
ingress implementation compatible with Knative, exact label schema, workflow/job
names, report format, fixture generation, and efficient metric collection. Any
choice that exceeds the budget, weakens environment isolation, or changes the
availability policy returns to the design decision rather than being implicit.

## Evidence and references

* Existing repo: `.github/workflows/deploy.yml`, `.github/workflows/preview.yml`,
  `generate.tm.hcl`, `hosts/dev-box/configuration.nix`; inspected in this review.
  This checkout is behind remote main; implementation starts from current main.
* [Flux environment structure and promotion](https://fluxcd.io/flux/guides/repository-structure/)
* [Kubernetes multi-tenancy and isolation limits](https://kubernetes.io/docs/concepts/security/multi-tenancy/)
* [UpCloud control-plane availability](https://upcloud.com/docs/products/managed-kubernetes/control-plane/)
* [UpCloud pricing](https://upcloud.com/pricing/)
* [UpCloud Essentials limits](https://upcloud.com/docs/getting-started/upcloud-essentials/)
* [UpCloud autoscaling overview](https://upcloud.com/docs/products/managed-kubernetes/autoscaling/)
* [UpCloud detailed node-scaling guide](https://upcloud.com/docs/guides/scale-managed-kubernetes-cluster/)
* [Knative request-driven autoscaling](https://knative.dev/docs/serving/autoscaling/)
* [k6 pass/fail thresholds](https://grafana.com/docs/k6/latest/using-k6/thresholds/)

Provider documentation checked 2026-10-15. Pricing and account-specific behavior
must be verified again when preparing the implementation's actual resource plan.
