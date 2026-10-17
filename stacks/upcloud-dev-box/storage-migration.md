# dev-box storage migration — 2026-10-17

## Objective and current checkpoint

Move `/data` from 20 GB MaxIOPS to 50 GB Standard by cloning a fresh stopped
snapshot. Retain the original disk and a verified recovery point. After the
attachment change completes, enable Simple Backup Week (`dailies`, `0900`).
Prove recovery in an isolated environment before proposing legacy cleanup.

**Checkpoint: preparation only. No shutdown, clone, import, attachment change,
backup policy change, or deletion has been performed.** PR #28 is the readiness
stage. It requires one approving review before merge; do not use the admin bypass.
The later stages must be separate reviewed PRs/applies, never one combined merge.

The coordinator runs on Mike's Mac. Use public SSH `dev@209.94.62.235` and the
UpCloud API; neither coordination nor recovery records may depend on dev-box
remaining available. Use the repository's SOPS workflow without printing secrets.

## Inspected baseline

| Item | Observed value |
|---|---|
| Server | `00f18c52-0c8b-4ada-982d-582b1a9f400f` |
| Public IPv4 / zone | `209.94.62.235` / `us-sjo1` |
| Actual plan | `STARTER-4xCPU-8GB`, 4 cores, 8192 MB |
| Plan inclusion | One eligible Standard disk up to 40 GB |
| Root | `01da1960-0299-4fef-8739-2bfb10aad259`, 50 GB Standard, `virtio:0` |
| Original `/data` | `012ff8f3-fd54-42d5-9634-3eea56db0ca8`, 20 GB MaxIOPS, `virtio:1` |
| Filesystem | Whole-device ext4, label `data`, UUID `9e4a70f4-bf84-431b-8842-9fd92eef5817` |
| Usage | About 14 GiB used, 5.5 GiB available at inspection; recheck before cutover |
| Backup rule | Original disk: daily, `0900` UTC, retention 7; root: none |
| Latest existing snapshot | `01bf7a2c-ab03-47a9-b63f-68da22a51656`, 2026-10-17 09:01:59 UTC |
| Existing recovery proof | Seven snapshots are online; application recovery has **not** been tested |
| Terraform | State lineage `2682e0ad-b11f-eba4-77ee-62862304c701`, serial 16 at inspection |
| Tool/provider | OpenTofu 1.11.6 (matches CI); UpCloud 5.45.0 |

Live Docker inventory: `surf-atlas-postgres-1` (Postgres 17, healthy),
`surf-atlas-spike-db` (stopped), `paceline-pg2` (Postgres 16, stopped). Three
Docker volumes include `surf-atlas_atlas_postgres`. Record the complete inventory
again before stopping. LifeData's Python status reported atlas 35, Roam 11094,
session 519. Include the LiveView endpoint in the later health check.

Uncommitted `infra` files include `flake.lock`, `flake.nix`, and
`hosts/dev-box/configuration.nix`. Other repositories and `.codex`/`.claude` state
also live under `/data/home/dev`. Preserve everything, including ignored/untracked
files, credentials, Git worktrees, SQLite WALs, permissions, ACLs and xattrs.
Do not reset repositories or delete session databases.

Existing Flexible recovery copies (all 20 GB, origin the original data disk):

| Created, 09:00 UTC cycle | Snapshot UUID |
|---|---|
| 2026-10-11 | `01f60dc9-cacb-4747-a77c-3871ceb0839f` |
| 2026-10-12 | `01124323-56ce-45b6-a125-d3ef96765a4b` |
| 2026-10-13 | `016bafdb-a5bd-4543-8393-32e81bf10848` |
| 2026-10-14 | `0140cd2c-6819-4935-b78d-62f487c523fa` |
| 2026-10-15 | `013a7cb6-b832-46e1-a1a0-5208b4490208` |
| 2026-10-16 | `0191c7a9-f56b-4b69-a4d5-9f009d636994` |
| 2026-10-17 | `01bf7a2c-ab03-47a9-b63f-68da22a51656` |

This is an inspection record, not a deletion list. The old rule continues rotating
these copies; refresh the inventory at cleanup. The stopped migration snapshot
will have a different UUID and must be recorded separately.

## Provider facts that determine ordering

Version 5.45.0 marks storage `tier` and clone source ID as requiring replacement.
Keep `upcloud_storage.data` at the observed original size/tier and retain its
`prevent_destroy`. Use a separate protected `upcloud_storage.data_standard`.
Create it by API clone, then import into a normal resource **without a clone
block**. This avoids a future dependency on a disposable snapshot's provenance.

The provider detaches removed devices before attaching new ones, then calls
`VerifyServerStarted` at the end of server Update, including when it was stopped.
Thus the new disk must be complete, online and 50 GB **before** the attachment
apply. Keep cloud-init, disko and bootstrap unchanged. Never attach both clones
to the same guest: their filesystem UUID and label match.

`enabled=false` deletes the server, its provider-managed root disk, bootstrap
resource, DNS and firewall resources. It is not a maintenance power control.
UpCloud converts Simple Backups to on-demand copies on server deletion or policy
disablement. They stop rotating and remain chargeable until explicitly deleted.
The provider's Delete calls DeleteServer and deletes the root template storage;
it does not enumerate/delete the backup inventory. Record and inspect orphaned
backups deliberately after any teardown.

## Stages and acceptance gates

### A — readiness (PR #28)

Enable `/data` autoResize while preserving by-label ext4 mounting. Fix the old
resource at 20/maxiops, keep its backups and destruction protection, and pin the
inspected provider version. A plan-only regression test supplies replacement
settings 50/standard and verifies that the original resource stays 20/maxiops.

Expected real plan: only recreate the runner-local sensitive bootstrap-key file;
no cloud changes. Main requires a PR and one approving review. After merge, wait
for **both** deploy.yml completion and a successful comin switch to that main
commit. Verify the deployed `/data` mount carries the configured growth behavior
(`x-systemd.growfs` for a systemd initrd, or the stage-1 resize action otherwise);
evaluating Git source alone is not deployment proof. Save the current booted generation and deployment commit.

### B — stopped snapshot, detached replacement and Terraform adoption

Prepare/review the next stage before downtime. It changes desired defaults to
50/standard and adds a separate protected normal storage resource; the server
still references the original disk. Do not merge a plan that creates a blank disk.

1. Confirm no competing deploy/apply, no pending comin switch, and public SSH/API
   access from the Mac. Keep the terminal and recovery records on the Mac.
2. Capture repository statuses and hashes of representative modified/untracked
   files; capture ownership/mode/xattr samples. Record Docker containers, images,
   volumes and database names/counts without dumping credentials. Record Codex
   thread IDs/counts and read-only SQLite integrity results using SQLite backup
   APIs where appropriate. Store confidential evidence in a mode-0700 local
   directory, never in a PR or the Nix store.
3. Preserve a completed existing snapshot and verify its readable content through
   a temporary isolated clone before relying on it as a recovery point. This is
   distinct from the later test of the new scheduled policy.
4. Stop application writers (including agent/build sessions), stop the running
   Postgres container with adequate timeout, stop Docker/socket, LifeData/search
   services, and comin. Gracefully power off the VM using systemd over public SSH.
   Confirm **stopped** through UpCloud. Do not treat SSH disconnect as proof.
5. Take an on-demand snapshot of the old disk while stopped; wait for `online`.
   Record its UUID/title/time/origin/size on the Mac and in the execution record.
   This snapshot is the clone source and is never included in blanket cleanup.
6. Clone that snapshot in `us-sjo1`, explicitly `tier=standard`, title
   `dev-box-data-standard`. Wait for online; then grow its backing storage to
   50 GB and wait for online again. Verify it has no attached server and no
   individual backup rule. No filesystem formatting or UUID/label change.
7. In the reviewed stage-B checkout, use `tofu import
   upcloud_storage.data_standard <new-uuid>` under SOPS with state locking.
   Inspect the real refreshed plan: original disk unchanged, server unchanged,
   no creation/replacement of either disk. Only reconcile intended labels/title
   if the clone inherited different metadata. Merge and wait for deploy success.

Example API payloads (run from the Mac under `sops exec-env`; no verbose curl):

```text
POST /1.3/storage/012ff8f3-fd54-42d5-9634-3eea56db0ca8/backup
{"storage":{"title":"dev-box-pre-standard-<UTC timestamp>"}}

POST /1.3/storage/<stopped-snapshot-uuid>/clone
{"storage":{"zone":"us-sjo1","tier":"standard","title":"dev-box-data-standard"}}

PUT /1.3/storage/<new-uuid>
{"storage":{"size":50}}
```

Never retry a creation after an unknown response without inventorying by title,
origin and timestamp; recover the returned object instead of making duplicates.

### C — attachment cutover (separate reviewed apply)

Change only `storage_devices.storage` and the active data output to the adopted
replacement. Retain an explicit output for the original rollback disk. Require
a real plan showing one in-place server update, no bootstrap replacement, no
root/cloud-init change and no disk destruction. Simple Backup remains absent.

The VM remains stopped from the snapshot until this apply. The provider starts
it after swapping the disks. Check UpCloud attachment inventory immediately:
root plus the new data disk; original detached. Check public SSH, filesystem
UUID/label and ext4 capacity, then file hashes/status/ownership/session data,
Docker volumes and database recovery, LifeData counts/endpoints and Tailscale
identity/Serve. Confirm initrd ext4 growth used the full 50 GB backing disk
(roughly 49 GiB after filesystem overhead), not merely that lsblk says 50G.
Recreate no application data and run no volume prune.

Downtime budget: **30–60 minutes for a same-zone 20 GB clone, growth, import,
completed reviewed stages and boot checks**, provided reviewers are available.
Clone latency, CI or review delays can extend this; this is an estimate, not a
measured duration. Do not restart the old disk between snapshot and cutover:
later writes would make the clone stale. Arrange reviews before the window.

### D — Simple Backup Week (subsequent reviewed apply)

After C is completed and healthy, verify root and replacement both have no
individual backup rule. Add only:

```hcl
simple_backup {
  plan = "dailies"
  time = "0900"
}
```

The detached original may keep its old Flexible rule during rollback protection.
Require the real plan to show only an in-place server backup-policy update.
Verify the API reports `0900,dailies`. At 09:00 UTC (02:00 PDT / 01:00 PST),
wait for an actual completed scheduled backup of **each attached disk**, record
their UUIDs/origins/timestamps, and verify policy/retention. The seven recovery
points build over seven days; a newly enabled policy has no historical points.
An on-demand snapshot does not prove the scheduled policy has run.

### E — isolated restore proof, then cleanup proposal

Clone a completed scheduled data backup into a separate temporary recovery
environment. Keep its network isolated: no cloned Tailscale identity, comin,
public app listeners, production jobs, or outbound credentials in use. Mount the
clone by explicit device, never the production label resolver. A writable clone
may replay its journal; do not alter the immutable backup or production disk.
Verify modified/untracked file hashes and permissions, Codex conversation
records and SQLite integrity, LifeData SQLite integrity and representative
searches, and Docker volume data. Start the appropriate Postgres major-version
image against **the clone only**, with networking disabled, and verify startup,
database queries and representative counts. Do not read private notes or rows
into public logs. Scheduled snapshots are crash-consistent; a listing or ext4
mount alone does not prove database/application recovery.

For full-VM-filesystem destruction recovery, clone root and data backups from
the same scheduled cycle into an isolated server and demonstrate that it boots
and opens recovered application/session data. Avoid production identity/network
collisions. If rebuilding root instead, the existing nixos-anywhere workflow
formats only `/dev/vda`; attach exactly one recovered ext4 `data` disk and use
the preserved credentials/identity deliberately after recovery checks.

Keep the original disk and stopped snapshot until the replacement **and this
scheduled-backup restore** pass. Then propose an itemized cleanup with UUID,
origin, title, size and cost for every legacy disk/snapshot/test resource.
Remove the old Flexible rule in a separate completed apply, then explicitly
review destruction-protection removal and deletion of only the retired disk.
Do not use state removal as deletion, globbed delete loops or backup-title-only
selection. Confirm the new policy and recovery points survive cleanup.

## Rollback

Before cutover, leave the original attachment and boot the original server if
aborting; do not later cut over to the stale clone without a fresh snapshot.
After cutover, stop writers and snapshot the new disk first. Record all writes
since cutover: the old disk is a frozen point-in-time copy, so simply reverting
attachments loses those writes. Export/reconcile application deltas deliberately
or obtain explicit acceptance of that loss. If Simple Backup is active, disable
it in a completed apply **before** attempting to attach a Flexible-backed disk;
inventory the resulting on-demand backups and their charges. Stop the VM,
detach the new disk, verify detached, reattach the old at virtio:1, and start.
Restore Terraform attachment configuration to match through a reviewed PR.
Never attach the two same-UUID filesystems together.

## Cost: actual account rates, USD before taxes

The billing API for October confirms USD and whole-disk billing: root charged
$0.4288 for 64 hours at 50 GB, not 10 GB; the original data disk charged
$2.8107 for 405 hours. Price API values are cents per hour. The current server
plan costs 3.5714 cents/hour with a 28-day monthly cap (~$24); storage is
estimated at 720 hours/month. The plan's 40 GB allowance is unused: the root
is too large and MaxIOPS is the wrong tier. After migration both 50 GB disks
are too large. Do not subtract 40 GB or charge only the root's 10 GB excess.

| Item | Current steady state | Target after legacy cleanup |
|---|---:|---:|
| STARTER-4xCPU-8GB | $24.00 | $24.00 |
| Root 50 GB Standard (0.0134 cents/GB/hour) | $4.82 | $4.82 |
| Data 20 GB MaxIOPS / 50 GB Standard | $5.00 | $4.82 |
| Seven 20 GB Flexible copies (0.0083 cents/GB/hour each) | $8.37 | $0 |
| Simple Backup Week base (0.7143 cents/hour, 28-day cap) | $0 | $4.80 |
| Week backups of both additional 50 GB disks (0.0083 cents/GB/hour) | $0 | $5.98 |
| **Total UpCloud run rate** | **$42.19** | **$44.42** |

Simple Backup's additional-storage price is a policy rate, **not seven times**
the per-GB rate. It now covers root too. IPv4 is marked part_of_plan=yes and
has no additional charge; current firewall/OS license charges are zero.
Route 53/S3 are existing shared AWS costs, outside this UpCloud total; they
are unchanged by this migration. Taxes, transfer overage and month length vary.

During rollback protection add ~$5.00/month for the detached 20 GB MaxIOPS
disk, ~$8.37/month for its seven rotating backups and ~$1.20/month for the
20 GB stopped snapshot: **$58.99/month total while all are retained**. Each
additional manual 20 GB snapshot adds ~$1.20/month. A temporary 50 GB Standard
restore clone adds ~$4.82/month prorated; temporary recovery compute/root
are additional. Using the same inspected STARTER-4xCPU-8GB plan with cloned
50 GB root and data disks and no backups costs ~$0.049114/hour for compute
and both disks (~$1.18 for 24 hours), with IPv4 included. Confirm this plan
and duration before creating the isolated server; smaller plans can be
selected after checking memory requirements and current rates.
Report exact retention duration and resource IDs in the execution record.

## References

- [Billing inclusion and backups](https://upcloud.com/docs/products/block-storage/billing/)
- [Price API](https://developers.upcloud.com/1.3/4-pricing/)
- [Resource billing API](https://developers.upcloud.com/api/1.3/account)
- [Clone and backup API](https://developers.upcloud.com/1.3/9-storages/)
- [Simple Backup lifecycle](https://upcloud.com/docs/products/block-storage/backups/)
- [Inspected storage provider](https://github.com/UpCloudLtd/terraform-provider-upcloud/blob/v5.45.0/internal/service/storage/storage.go)
- [Inspected server provider](https://github.com/UpCloudLtd/terraform-provider-upcloud/blob/v5.45.0/internal/service/server/server.go)
