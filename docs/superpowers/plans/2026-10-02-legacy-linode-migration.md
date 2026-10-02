# Legacy Linode Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This initial operational plan is for review; provisioning and retirement require the inventory decisions below first.

**Goal:** Remove personal email DNS and retained workloads from the legacy Linode server while preserving needed data and setting up `mike.pixor.net` as the existing account's Bluesky handle.

**Architecture:** Move `pixor.net` authoritative DNS to a dedicated Route 53 stack independently of compute migrations. Inventory and classify each legacy workload, back up its data, then move or archive it using the hosting patterns in this repository. Retire `epic3` only after every remaining dependency has an explicit disposition.

**Tech Stack:** BIND, AWS Route 53 and Amazon Registrar, Terramate, OpenTofu, SOPS, NixOS/comin, existing Hetzner/UpCloud stacks, and workload-specific runtimes identified during inventory.

**Spec:** [Findings and migration scope](../../migrations/legacy-linode/README.md).

## Global Constraints

- Preserve `mike@pixor.net` delivery and existing mail authentication records.
- Use the existing DID `did:plc:dtf7zmcsjtwedsdbdaxhfkrj` for `mike.pixor.net`.
- Preserve unrelated staged and unstaged changes in `/etc/bind`.
- Keep DNS cutover separate from website/database target changes.
- Retain legacy DNS through the delegation cache window and until all other delegated domains are handled.
- Store private backups and secrets outside Git; use SOPS for credentials needed by this repository.
- Use TDD for new software and infrastructure implementation: tests first, observed failure, implementation, observed pass.
- New compute placement remains undecided until retained workloads and data requirements are known.

## Review Focus

- Both `ns1` and `ns2` live on `epic3`; a single host failure removes both DNS endpoints.
- Wildcard records, omitted owner names, and names without trailing dots must preserve their effective DNS meaning.
- Fastmail apex routing coexists with legacy subdomain SMTP/IMAP services; inventory both before retirement.
- Unreadable database and mail directories make unprivileged disk scans incomplete; obtain consistent backups and prove restore.
- The existing CI IAM policy cannot create a hosted zone or change registrar nameservers; verify the actual operator identity and permissions.

## Task 1 Stabilize the legacy host

**Deliverable:** Enough free disk space to maintain DNS, with unused Jenkins disabled.

- [x] Identify the disk consumer: active Jenkins log approximately 36.24 GiB; backup files only 12.26 MiB total.
- [x] Confirm cleanup: root filesystem 55% used, 36 GB available, and active Jenkins log empty.
- [x] Confirm Jenkins disabled and absent from the running-service listing.
- [ ] Record remaining disk consumers, backup status, and available space using a privileged scan; do not remove application data during discovery.
- [ ] Verify free space remains stable and DNS answers continue after cleanup.

## Task 2 Publish and activate the Bluesky handle

**Files:** [Runbook](../../migrations/legacy-linode/bluesky-handle.md), [candidate zone](../../migrations/legacy-linode/evidence/pixor.net.with-atproto.zone).

- [x] Resolve `flyingyeti.com` through DNS and the public Bluesky API; confirm the same DID and its current DID document.
- [x] Check current `_atproto.mike.pixor.net`: no `did=` record, only wildcard Keybase TXT.
- [x] Prepare the minimal addition and serial `2026100201`; validate the candidate with `named-checkzone` on `epic3`.
- [x] Confirm the existing zone is committed; Mike installed the candidate with interactive sudo, validated it, and reloaded BIND. Use existing Git history for rollback.
- [x] Verify the TXT and serial at both authoritative IPs; verify the TXT at Cloudflare, Google, and the public Bluesky resolver.
- [x] Verify apex MX, SPF, and all three DKIM CNAMEs remain unchanged.
- [x] Save `mike.pixor.net` in the existing Bluesky account and verify the DID document claims it; confirmed at 12:20 UTC on 2026-10-02.
- [x] Update findings with DNS publication evidence and preserve the installed zone candidate.
- [x] Record final account activation evidence in the findings and verification record.
- [ ] Refresh the live zone export before the Route 53 migration.

## Task 3 Complete the legacy inventory

**Files:** Add `docs/migrations/legacy-linode/inventory.md` with service/domain, evidence, data location, runtime, consumers, backup, and disposition columns.

- [ ] With admin access, list enabled services, listeners, root/user cron jobs, timers, Apache vhosts, certificate renewal jobs, database instances, mail routing, and repository services.
- [ ] Enumerate BIND zones and compare their current public delegation. Distinguish actively delegated domains from obsolete local files.
- [ ] Map Apache vhosts to web roots, uploads, databases, external services, and background jobs. Record runtime versions and recent use without exposing private log contents.
- [ ] Inventory MySQL/PostgreSQL, Postfix/Dovecot mailboxes and queues, mailing lists, Gitolite, Subversion, Jenkins state, and user home archives.
- [ ] Classify each item with Mike as retain and migrate, archive, or retire. Do not infer disuse from old modification dates alone.
- [ ] Back up classified data to protected storage and test restoration; record storage location, checksums where appropriate, and retention.

**Acceptance:** Every discovered domain/service has a disposition, dependency list, and backup/restore requirement. Record inaccessible or unresolved items explicitly.

## Task 4 Prepare the Route 53 zone under infrastructure management

**Proposed files:** `stacks/pixor-dns/stack.tm.hcl`, `versions.tf`, `main.tf`, `records.tf`, and `outputs.tf`; DNS migration fixtures and tests chosen in the focused stack implementation plan. Review the shared policy in `stacks/tfstate-backend/main.tf` if CI will own hosted-zone lifecycle.

- [ ] Confirm the AWS account/profile for the hosted zone and the account owning the Amazon registration. Inspect the actual IAM permissions before choosing bootstrap versus a scoped policy update.
- [ ] Refresh and canonicalize the current live BIND export, including the handle record. Expand relative names and inherited owners with BIND's zone parser, preserving effective records.
- [ ] Review existing oddities: `colo.pixor.net` and `kyle.colo.pixor.net` omit trailing dots, and the Keybase TXT inherits the wildcard owner. Preserve current answers at cutover; repair legacy semantics in a separate change.
- [ ] Before implementing conversion or stack code, write failing checks for exact apex/wildcard MX, SPF, all three DKIM records, the handle DID, ACM validation, other CNAME targets, and relative-name/owner-inheritance fixtures.
- [ ] Implement a dedicated public `pixor.net` zone and its retained records using the existing Terramate/OpenTofu/S3 conventions. Keep AWS-generated apex SOA and NS records. Protect the zone from accidental destruction and expose its assigned nameservers.
- [ ] Run the focused tests and repository formatting/validation checks. Review the plan for unrelated changes and ensure it does not replace compute or alter existing record targets.
- [ ] Provision the new zone only after reviewing the concrete plan. Do not change delegation in the same step.
- [ ] Query every assigned AWS nameserver directly and compare all non-SOA/non-apex-NS RRsets to the canonical legacy export. Test the wildcard and legacy names explicitly.

**Acceptance:** The new zone is under one documented management path and passes record parity checks before receiving public delegation. If a zone is created manually during bootstrap, import it into state before subsequent management.

[AWS migration guidance](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/migrate-dns-domain-in-use.html) describes staging a zone before delegation.
[AWS zone import documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-creating-import.html) covers BIND name expansion and treatment of apex SOA/NS records.

## Task 5 Cut over pixor.net DNS

- [ ] Freeze DNS edits or mirror them to both providers during the transition. Capture old nameserver names and glue addresses for rollback.
- [ ] Recheck DS/DNSSEC state and NS TTLs. Lower controllable NS TTLs ahead of cutover and wait out previous cache lifetimes; the observed parent referral TTL is 172800 seconds, so plan a 48-hour window and do not assume a lower child-zone TTL removes it.
- [ ] Confirm all four assigned AWS nameservers answer correctly, including mail authentication and `_atproto.mike.pixor.net`.
- [ ] Change nameservers at Amazon Registrar to the exact four assigned Route 53 servers. Registration remains with Amazon; no domain transfer is needed.
- [ ] Verify `.net` delegation, public recursive answers, email receipt and sending from `mike@pixor.net`, DKIM authentication, and Bluesky's bidirectional handle identity.
- [ ] Keep the BIND zone available and consistent for at least the observed 48-hour cache window after cutover; extend the overlap if actual maximum TTLs or resolver checks require it.
- [ ] If validation fails, correct record discrepancies or restore the saved registrar delegation, keep both providers serving, and monitor until caches converge. Registrar rollback is not instantaneous.
- [ ] Record cutover time and evidence. Do not shut down BIND until every other actively delegated domain on `epic3` is migrated or explicitly retired.

**Acceptance:** Public delegation uses Route 53, personal mail and the new handle work, and legacy DNS is no longer needed for `pixor.net` after cache expiry.

## Task 6 Move or archive retained workloads

- [ ] For each retained service, select the target and write a focused design/implementation plan based on the inventory. Evaluate the existing paused Hetzner application stack and NixOS hosting patterns without automatically placing production services on the dev box.
- [ ] Define storage, secrets, backups, runtime compatibility, networking, and rollback. Use separate stack/state ownership where replacement of one host must not affect another service's data.
- [ ] Implement using TDD, restore into the target, and test with staging names or direct host routing before changing production DNS.
- [ ] For stateful applications, plan the write freeze and final consistent database/upload synchronization. Test full application behavior, not only HTTP status.
- [ ] Change individual records, observe the service through its cache window, and keep rollback copies until acceptance.
- [ ] Archive classified repositories and historical datasets; verify archive readability before removing originals.

**Acceptance:** Each inventory item has verified migration or archival evidence, and any remaining legacy consumer is explicitly tracked.

## Task 7 Retire the legacy server

- [ ] Verify no remaining domain delegates to either legacy nameserver address and no service still needs `epic3` for DNS, SMTP, storage, jobs, or hosting.
- [ ] Verify protected backups can be restored and record retention decisions for historical data.
- [ ] Disable remaining legacy services after their replacements are accepted; observe a reversible shutdown period before deleting the Linode instance or disks.
- [ ] Remove obsolete DNS records, glue where no longer needed, credentials, monitoring entries, and provider resources only after dependency checks.
- [ ] Record final state, migrated destinations, retained archives, and closure evidence in the migration findings.

**Acceptance:** All dependencies are accounted for, replacements and archives are verified, and retirement introduces no unresolved email or hosting dependency.
