# Hosting options in October 2026

Research date: October 16, 2026. This comparison preceded the decision to use
Kubernetes with Docker, Helm, GitHub Actions, and Argo CD. See the
[current design](../superpowers/specs/2026-10-15-kubernetes-hosting-design.md).
The subsequent [cost model](2026-10-16-kubernetes-cost-model.md) uses the revised
budget: under $100/month for new infrastructure, excluding dev box and legacy
hosting. Recommendations below record the research-stage shortlist and original
budget scope, rather than the subsequent tooling decision.

**Recommendation: compare an existing self-hosted PaaS with a managed PaaS before
building a Kubernetes platform.** Kubernetes remains a candidate when automatic
multi-server scheduling and portability justify owning the cluster. Learning it is
valuable, but production hosting need not carry the entire learning experiment.

## Where the compute comes from

| Approach | Where apps run | What we operate |
| --- | --- | --- |
| Coolify, Dokploy, Dokku, CapRover | VPSs rented from UpCloud, Hetzner, or another provider | Servers, deployment software, backups, capacity |
| Railway, Render, Northflank | Provider-managed compute | Apps, configuration, data lifecycle, usage limits |
| Fly.io | Fly Machines, which are provider-hosted VMs | App deployment and Machine/volume configuration |
| Cloud Run | Google-managed container instances | App containers, service configuration, external data |
| Kubernetes with a PaaS such as Kubero | Worker VMs in our chosen cloud | PaaS plus cluster integrations; managed Kubernetes can offload the control plane |

A dashboard, more app copies, more servers, and waking an idle app are separate
capabilities. A product advertising “scaling” may provide only one of them.

## The serious candidates

| Option | What fits | What needs extra work or changes the choice |
| --- | --- | --- |
| **Coolify** | Dashboard, domains, metrics, PR previews including Compose services; close/merge cleanup. Closest self-hosted starting point for this workflow. [Previews](https://coolify.io/docs/applications/deployments/preview-deployments). | No verified native HTTP sleep or demand-driven cloud-node autoscaling. It does have Hetzner server provisioning. Multi-server app deployment requires an external load balancer; the current feature excludes Compose apps and apps with persistent storage. [Limits](https://coolify.io/docs/core/infrastructure/scaling/multi-server-deployments). |
| **Dokploy** | Dashboard and Swarm-based replicas across machines; useful middle ground if multi-host deployment matters soon. [Deployment models](https://docs.dokploy.com/docs/core/deployment-options). | Native previews cover applications; complete Compose PR environments remain an [open feature request](https://github.com/Dokploy/dokploy/issues/2028). Cloud-node autoscaling is separate work. |
| **Dokku** | Small CLI-oriented deployment system; current core also supports a [k3s scheduler with KEDA HTTP autoscaling](https://dokku.com/docs/deployment/schedulers/k3s/), including zero replicas. | Free core is not the integrated dashboard requested here. Official [Pro UI/API](https://pro.dokku.com/) is advertised at $849 lifetime and in development. Kubernetes node provisioning remains separate. |
| **Railway** | Managed dashboard, domains, [PR environments](https://docs.railway.com/environments), automatic cleanup, sleeping services, API/CLI. Strong convenience baseline. | [Horizontal replicas are manual](https://docs.railway.com/deployments/scaling); vertical scaling is automatic. Background network activity can prevent sleep. Full previews multiply running services and databases. |
| **Northflank** | Managed dashboard, autoscaling, substantial [preview/QA automation](https://northflank.com/docs/v1/application/release/set-up-preview-blueprints), templates, expiry and teardown workflows. | [Zero replicas](https://northflank.com/docs/v1/application/scale/scale-instances) is not verified to provide HTTP wake-on-request. Test idle costs and the particular services needed before treating it as serverless. |
| **Cloud Run** | [Automatic horizontal scaling and HTTP scale-to-zero](https://docs.cloud.google.com/run/docs/about-instance-autoscaling) with ordinary container images. Strong candidate for intermittent stateless backends. | Preview orchestration, databases and domain routing need assembly. [Native domain mapping](https://docs.cloud.google.com/run/docs/mapping-custom-domains) remains Preview and is not recommended for production; Google suggests a load balancer or Firebase Hosting. |
| **Fly.io** | Sleeping/waking VMs and portable container deployment, without owning a Kubernetes cluster. | [Autostart](https://docs.fly.io/launch/autostop-autostart/) wakes existing Machines; it does not create more. CI must manage PR environments; disks and stopped root filesystems still cost money. |
| **Kubero on Kubernetes** | Free [PaaS UI/operator](https://github.com/kubero-dev/kubero), PR review apps and cleanup, metrics, API/CLI, application autoscaling. A fairer Kubernetes comparison than our bespoke stack. | We still own cluster/storage operations. Advertised sleeping behavior needs verification. Bundled database addons are explicitly not HA-ready. Release maintenance needs investigation below. |

## Other options worth distinguishing

**CapRover** is a credible simpler dashboard on Swarm. It supports replicas and
clusters; persistent apps are tied to one node. Its August 2026 release added
simplified Compose support. PR lifecycle and automatic sleep would need additional
integration. [Scaling](https://caprover.com/docs/app-scaling-and-cluster.html),
[Compose release](https://github.com/caprover/caprover/releases/tag/v1.15.0).

**Kamal and Portainer** are useful building blocks. Kamal deploys containers to
configured servers; Portainer manages containers and stacks. Neither supplies the
complete preview/data/expiry workflow out of the box. Choosing them means owning
more glue code. [Kamal](https://kamal-deploy.org/docs/configuration/),
[Portainer Git stacks](https://docs.portainer.io/user/docker/stacks/add).

**Nomad** has a real application and node autoscaler, installed separately. It is
an alternative orchestrator, but choosing it still leaves the developer PaaS and
preview workflow to assemble. [Autoscaler](https://developer.hashicorp.com/nomad/tools/autoscaling).

**Render** offers managed full-stack previews, but the Pro workspace is $25/month
before compute. Autoscaling is disabled in its preview environments, so they cannot
stand in for a production-scaling rehearsal. [Pricing announcement](https://render.com/blog/better-pricing-for-fast-growing-teams),
[Blueprint behavior](https://render.com/docs/blueprint-spec).

**Cloudflare static hosting/Workers** deserves a separate role: the current outliner
is a static frontend, so it does not need a dedicated container cluster. Static
asset requests are free; Workers Paid starts at $5/month. Provider-specific backend
APIs would increase migration work. [Pricing](https://developers.cloudflare.com/workers/platform/pricing/).

**Qovery and Porter** are difficult budget fits: Qovery's published Starter plan
is $299/month billed yearly, plus cloud; Porter charges $13/vCPU-month and $6/GB-month for
management in addition to underlying cloud costs. These are current commercial
plans, not a claim that every component they publish is paid.
[Qovery](https://www.qovery.com/pricing), [Porter](https://www.porter.run/pricing).

## What community discussions actually support

The evidence is mixed, not a consensus that one panel is universally reliable.

- In the **2026 HN Compose discussion**, operators describe years of successful
  deployments using versioned images, health checks and rollback. Others argue
  for Kubernetes when automated failover and scheduling are required. This
  supports choosing by required behavior rather than app count alone.
  [Discussion](https://news.ycombinator.com/item?id=47962032).
- A **September 2026 Reddit comparison** includes successful Coolify and Dokploy
  users, plus a Dokku user reporting memory pressure on a small Dokploy VPS.
  These are useful test cases, not comparable benchmarks.
  [Discussion](https://www.reddit.com/r/selfhosted/comments/1wapo2r/dokploy_vs_coolify_in_production/).
- A **March 2026 Dokku-to-Coolify thread** has both an experienced user staying
  with Dokku after a trial and Coolify users reporting trouble-free operation.
  Claims that AI contributions explain reliability are opinions, not established
  causation. [Discussion](https://www.reddit.com/r/coolify/comments/1rsx4nu/moving_from_dokku_to_coolify/).
- The **2025 HN Coolify thread** is substantial, but complaints about specific
  missing features should not be treated as current without verification.
  [Discussion](https://news.ycombinator.com/item?id=43555996).

These are self-selected reports, sometimes mixed with author promotion. They do
not establish market share or prove that small servers fail as soon as traffic
arrives. We need load measurements for our app.

## Changes and emerging tools found on GitHub

**Coolify's Swarm integration is deprecated**, with removal planned for v5; its
docs advise against new Swarm deployments. This does not mean Docker Swarm itself
is deprecated. Dokploy and CapRover remain distinct Swarm options.
[Current Coolify guidance](https://coolify.io/docs/core/infrastructure/scaling/docker-swarm).

**Uncloud** connects Docker hosts through WireGuard and deploys Compose services
across them. It is a promising portable middle ground, with an actual university
adoption report, but explicitly pre-1.0. It is not yet verified here as a complete
replacement for dashboard, preview lifecycle, sleep and node autoscaling.
[Repository](https://github.com/psviderski/uncloud),
[Radboud adoption](https://cncz.science.ru.nl/en/news/2026-04-15_uncloud/).

**ZaneOps** combines Swarm, a dashboard, previews and environment management.
**OpenRun** offers declarative deployments on Docker or Kubernetes, idle app
sleeping and a console; its documented model does not accept whole Compose stacks.
Both deserve a small trial, rather than selection from feature lists alone.
[ZaneOps](https://zaneops.dev/), [OpenRun](https://github.com/openrundev/openrun).

GitHub release checks: Uncloud v0.21.0 (Oct 2, 2026), ZaneOps v1.15.1 (Sep 25),
OpenRun v0.20.3 (Oct 14). Kubero's latest published UI release is v3.1.1
(Sep 17, **2025**); its operator repository also last reports a push that day,
although the UI repository has October 2026 commits. That calls for checking the
supported deployment/update path, not declaring the project abandoned.
[Uncloud release](https://github.com/psviderski/uncloud/releases/tag/v0.21.0),
[ZaneOps release](https://github.com/zane-ops/zane-ops/releases/tag/v1.15.1),
[OpenRun release](https://github.com/openrundev/openrun/releases/tag/v0.20.3),
[Kubero releases](https://github.com/kubero-dev/kubero/releases),
[operator](https://github.com/kubero-dev/kubero-operator).

## What the agent boom changes

The useful direction is a repeatable deployment interface agents can operate.
Coolify, Dokploy and Portainer have official MCP interfaces; a special AI-branded
hosting platform is not necessary to gain that interface.
[Coolify MCP](https://coolify.io/docs/mcp/how-mcp-works),
[Dokploy MCP](https://github.com/Dokploy/mcp),
[Portainer MCP](https://github.com/portainer/portainer-mcp).

An AWS sample demonstrates a valuable rule: before an agent tests a preview,
both deployment status and the app's health response must identify the exact
commit. A reusable URL alone can point at stale code.
[Agent-preview sample](https://github.com/aws-samples/sample-eks-agent-pr-preview-url).

Emerging systems also reduce duplicated environments. Railway has focused PR
environments; mirrord's Enterprise preview feature runs changed services against
shared staging dependencies. Shared dependencies require deliberate data isolation;
they cannot safely substitute for all migration or infrastructure tests.
[Railway](https://docs.railway.com/environments),
[mirrord preview design](https://github.com/metalbear-co/docs/blob/main/docs/use-cases/preview-environments.md).

Agent execution environments are another category. Dagger Container Use gives
agents isolated development environments; that does not make it a production
hosting platform. [Repository](https://github.com/dagger/container-use).

Our proposed practices, informed by these examples:

1. Build in CI, deploy versioned images, and keep production away from build spikes.
2. Create previews for changes worth inspecting; cap simultaneous environments,
   cancel superseded builds, and verify expiry removes data and other paid resources.
3. Use disposable databases or branches, with their own credentials and fixtures.
   Neon is one managed option; sleeping compute does not remove storage/history
   charges, and branches should expire. [Neon billing](https://neon.com/pricing).
4. Keep disruptive infrastructure and load tests in separate, temporary QA capacity.
   On a VPS platform this can be another VPS; it does not require Kubernetes.
5. Let agents use reviewed commands and configuration. Keep the running desired
   configuration and cleanup rules deterministic and understandable without an agent.

## Cost and a practical decision

Compare **active environment-hours and memory**, not PR count. Illustratively,
1,000 previews/day kept for four hours average about 167 concurrent environments.
A 20-minute lifetime reduces that to about 14, before accounting for bursts.
A large PR count does not justify automatically retaining a full stack for each PR.

Railway's $5 Hobby minimum includes $5 usage; it is not $5 for unlimited hosting.
Its service memory rate is about $10/GB-month, before CPU, disks and traffic.
Ten continuously running 1GB previews would therefore consume about $100/month
in memory alone. [Pricing](https://railway.com/pricing).

For fixed VPSs, sleeping apps frees capacity but usually does not reduce the VM
bill. For metered services, test actual sleep behavior, cold starts and retained
storage. For Kubernetes, include the always-running platform components and the
work of upgrading and recovering them. Agents reduce some labor; they do not
remove these resources or responsibilities.

My current shortlist for a bounded comparison is **Coolify, Railway, and a packaged
Kubernetes option**. Use Dokploy as the Swarm contender if near-term multi-host
replicas outweigh turnkey Compose previews. Use Cloud Run as the reference for
true zero-to-many HTTP scaling; Northflank is worth testing if rich QA automation
and automatic replicas matter more than automatic sleeping.

Run the same small container app plus database through preview creation, update,
cleanup, rollback, a platform upgrade, and bounded load. Record idle RAM, time
spent operating it, recovery behavior and total estimated bill. Kubernetes should
win on those results, not merely on familiarity or interest. Keep the outliner's
static delivery independent of this choice.

This is a source-backed shortlist, not a measured platform benchmark. The actual
dev-box and legacy bills still determine how much of the $100–150 total remains.
