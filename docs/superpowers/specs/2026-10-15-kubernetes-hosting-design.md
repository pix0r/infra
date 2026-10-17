# Hosting plan: Kubernetes with standard tooling

Updated October 16, 2026. **Agreed direction:** Kubernetes, Docker, Helm,
GitHub Actions, and Argo CD. The shared chart is optional. Nothing has been deployed.
[Alternatives research](../../research/2026-10-16-hosting-options.md) records the
comparison preceding this decision. Provider choice and cost validation remain open.

## What each application owns

```text
Dockerfile                    # Container build
compose.yaml                  # Optional local development stack
deploy/values.yaml            # App settings for the shared Helm chart
.github/workflows/deploy.yml   # Calls a reusable build/deploy workflow
```

The app owns its port, health endpoint, resource needs, and process configuration.
The infra repo owns the shared chart and workflow, cluster services, environment
configuration, and deployed image digests. Argo CD deploys from Git. Pin chart and
workflow versions per app. Keep secret values outside Git, isolated by environment.

Onboarding registers a repository, domain, resource allowance, and secrets. CI
builds and publishes an image; deployment records its exact digest and app-config
revision. Promote the same artifacts through QA to production. Define the scoped
authentication and GitOps update mechanism during implementation planning; OIDC
requires an explicit trust integration, and is not automatic cluster authorization.

There is no custom deployment language or required homemade CLI. Compose remains
optional for local development; arbitrary Compose files are not automatically
converted to Kubernetes. Standard Helm commands expose the rendered resources.

An app may replace the shared chart with its own chart, Kustomize, plain manifests,
or a vendor chart while retaining CI, Argo CD, routing, and observability. Avoid
adding endless switches to the shared chart. Cluster-wide operators, storage
drivers, or privileged access require an explicit infra change.

## Compute comes from UpCloud virtual servers

The starting candidate is **UpCloud Managed Kubernetes**, with apps running on
**UpCloud virtual machines (VMs)**. A Kubernetes “worker node” is one of these VMs, essentially
a VPS. Several apps can share a VM. Kubernetes places and restarts their
containers; an autoscaler requests additional VMs from UpCloud when needed.

UpCloud runs the Kubernetes management service, called the control plane.
We would configure the apps, scaling, networking, and storage. This is one
candidate architecture; we have not committed to a provider or bought capacity.

## What runs where

| Resource | Location | When it runs |
| --- | --- | --- |
| Existing dev box | Its existing UpCloud VM | As today; separate from production |
| Production apps | Start with one new UpCloud worker VM | Always; allow a second VM when needed |
| Dashboard and monitoring | On production worker VMs | Always; private access |
| PR previews | A separate temporary UpCloud Kubernetes cluster, initially one worker VM shared by previews | Created for requested previews; deleted after the last one expires |
| QA / staging | Another temporary UpCloud cluster, initially one or two worker VMs | Only during release, upgrade, or load tests |
| Load generator | Separate temporary compute outside the QA workers | Only during load tests |
| App databases, if needed | Initially on production workers with separate persistent UpCloud disks | Data survives app restarts and worker replacement; backups stored separately |

So the ordinary footprint is **the existing dev box plus one production VM**,
with UpCloud also hosting the control plane. Preview and QA servers add temporary
costs. They are separate so a broken infrastructure test cannot take down production
or interrupt an active preview. Region and VM sizes still need pricing and testing.

App domains point to an UpCloud load balancer, which sends requests to the right
app on the worker VMs, with automated TLS. Use Argo CD for deployment visibility
and Grafana for resource graphs; include metrics, centralized logs, and alerts
with bounded retention. Verify domains, deployment status, and usage are easy to
find before deciding whether an additional cluster UI is needed. Specific gateway
and telemetry components remain implementation choices.

## How scaling works

More traffic -> start more copies of the app -> if those copies cannot fit,
create another UpCloud VM. When demand falls, remove spare app copies and then
unneeded VMs. We must install/configure this automation and set capacity limits;
new capacity takes time to start. The initial proposed production limit is two VMs.

For suitable HTTP apps, evaluate Knative for stopping idle copies and waking them
on a request; measure its overhead before adoption. **Production keeps at least
one VM running** for routing and platform services. Databases and monitoring do
not disappear when an app sleeps.
To eliminate unused preview/QA compute charges, delete those temporary clusters.

This requires apps that can safely run multiple copies. The current outliner is
a static frontend with browser-local data; a future sync backend needs its own
storage and scaling design.

## Previews and testing

Request a preview on a PR to get a URL and disposable test data. Proposed defaults:
three previews maximum, renewable four-hour lifetimes, automatic removal when the
PR closes or the lease expires. No production data or credentials in previews.
Use Argo CD PR integration; expiry, quotas, and data cleanup need additional
automation. Database migrations require an app-specific recovery strategy;
rolling back an image does not undo a schema change.

Request QA for a release candidate. Test the app, then deploy the exact same built
image to production after review. For infrastructure changes, create QA matching
current production and rehearse the upgrade there. Use production-sized resources
when measuring capacity. Keep reports; delete test resources, even after failures,
using cleanup automation outside the temporary clusters. Test backups and restore
before relying on the platform for durable data.

## Cost and the remaining decisions

The **$100–150/month ceiling includes everything**, including the dev box, legacy
hosting, disks, backups, networking, and temporary tests. The earlier budget split
was an allocation, not a verified quote; it did not establish that this fits.

UpCloud offers a free Development control plane, but charges for worker VMs.
That free plan has no high availability. Starting with it and one worker is the
low-cost option; it does not promise uninterrupted service. We need to price the
availability alternatives before choosing. More workers alone do not make the
database or control plane resilient.

Next: inventory the actual existing bill, price the VMs and supporting services,
and measure whether the dashboard/scaling stack fits a small worker. Validate
deploy, preview, promotion, rollback, restore, and cleanup for one app. Adding a
second ordinary app should require settings and a push, not a new infra project.
Then agree on cost and acceptable downtime before provisioning. Self-managed k3s on UpCloud
VMs remains an alternative if managed Kubernetes does not fit; we would then also
operate the control plane and arrange automatic VM creation ourselves.

Provider references, checked October 16, 2026:
[worker billing and control-plane plans](https://upcloud.com/docs/products/managed-kubernetes/billing/),
[automatic worker scaling and its limits](https://upcloud.com/docs/products/managed-kubernetes/autoscaling/).
