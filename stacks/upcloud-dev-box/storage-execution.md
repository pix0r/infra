# dev-box migration execution record

Coordinator: Mike's Mac, public SSH/control-plane access. Times below are UTC.
No credentials, application content or private file manifests belong here.

## Readiness — completed 2026-10-17

- PR #28 merged at 22:10:45, main commit `1e17376844646dbe34f6edc1aecbb99e7a1402fe`.
- Terraform Deploy run `39073992333` succeeded. No cloud disk/server changes.
- Comin switch succeeded at 22:11:51; deployment `7ec0b20c-58cb-4f68-8375-6be60adcfffd`.
- Live system: `/nix/store/ybpvcc6ka674qayl4g6hn6r5l81fqqs9-nixos-system-dev-box-26.05.20260914.c3eea5b`.
- Live fstab: `/dev/disk/by-label/data /data ext4 x-systemd.growfs,x-initrd.mount 0 2`.
- Original ext4 disk remains 20 GB and attached; the later maintenance actions are recorded below.

## Private baseline — captured while production is online

The mode-0700 directory `/private/tmp/dev-box-migration-20261017` on the Mac holds
private file hashes/statuses, modes and owners for eight repositories, Docker
inventory/database schema counts, Tailscale identity/Serve configuration and
SQLite checks. Refresh after writers are stopped before taking the clone source.

- Six Codex SQLite quick checks returned `ok`; state database has 323 threads.
- Both LifeData index SQLite quick checks returned `ok`.
- Agent databases, WAL/SHM files and history remain intact.
- Tailscale reports Running with the existing dev-box identity.

## Temporary preflight recovery resources — restore test passed

These are temporary API-created test resources, separate from production Terraform:

| Resource | UUID |
|---|---|
| Fresh Ubuntu recovery helper | `00e0af6f-91ec-4a8a-a312-28541c4e8a86` |
| Helper root: 20 GB Standard | `01e3ad13-b792-4bb5-88c5-ee62a4720c44` |
| Helper public IP | `95.111.213.244` |
| Existing source backup, 2026-10-17 09:01:59 | `01bf7a2c-ab03-47a9-b63f-68da22a51656` |
| Preflight restore clone: 20 GB Standard | `012d4b6a-972c-461a-9384-26ae094d2c0d` |

Helper plan: STARTER-1xCPU-2GB, root within the 20 GB allowance; ~1.0416
cents/hour plus 0.268 cents/hour for a separately billed 20 GB restore clone
(~$0.013096/hour total). Its SSH key is local to the Mac's private evidence
directory. No cloned production OS, comin or Tailscale identity is booted.
The existing backup clone completed and was attached only to the helper. Its
ext4 UUID/label and sampled ownership/modes survived. Eight recovered SQLite
databases passed quick_check; the snapshot has 295 Codex threads. Three
representative uncommitted infra files and the stable Outliner Cargo.toml matched
the live hashes. The PostgreSQL 16 cluster completed automatic crash recovery,
opened paceline_dev, and answered schema/statistics queries with networking
disabled. The container was stopped and clone unmounted afterward. Production
remained online throughout this test.

This 09:00 UTC backup predates the current surf-atlas Postgres 17 volume and
newer agent conversations (the live baseline has 323 threads). The upcoming
stopped snapshot is therefore necessary to preserve current state; this test
does not claim that the old snapshot contains later writes.
These resources must be itemized for cleanup; do not delete the source backup.

## Pending stages

- B / PR #29: merged and deployed successfully; imported replacement adopted without cloud changes.
- C / PR #30: merged and deployed; replacement attached and post-boot checks passed.
- D / PR #31: subsequent Simple Backup Week apply.
- E: completed scheduled root/data backups, isolated application recovery proof,
  then a separately reviewed itemized legacy/test-resource cleanup proposal.

## Maintenance and fresh snapshot — 2026-10-17

- Writers stopped beginning about 22:19 UTC: comin, both search services,
  PostgreSQL 17 (graceful Docker stop), Docker/socket and Tailscale. Remaining
  dev-user agent sessions were terminated before the final manifest and sync.
- Quiesced baseline: 8 repositories, 324 Codex threads; all SQLite checks `ok`.
- Guest power-off requested, then UpCloud confirmed `stopped` before snapshot.
- Fresh on-demand snapshot: `01179612-bef1-4367-9ef4-a21d172aa10d`, title
  `dev-box-pre-standard-20261017T222204Z`, created 22:22:05 UTC, 20 GB, origin
  `012ff8f3-fd54-42d5-9634-3eea56db0ca8`.
- Detached Standard replacement clone: `019dbaf2-d708-4deb-9bde-cd222c4a912d`,
  title `dev-box-data-standard`, source the fresh stopped snapshot above.
- Original disk is retained at 20 GB MaxIOPS with its Flexible rule and
  destruction protection. It was detached by the later cutover below.
- Preflight recovery clone is now detached and retained; helper has only its
  fresh Ubuntu root. It cannot accidentally mount both same-label clones.

## Replacement preparation

The replacement completed synchronization and was grown detached to 50 GB.
The resize API response timed out, so its outcome was checked with GET rather
than retrying the mutation: UpCloud confirmed 50 GB Standard, online, no server
attachments and no individual backup rule. Original disk and stopped snapshot
remain unchanged. Import into `upcloud_storage.data_standard` succeeded while the VM remained
stopped. The refreshed adoption plan shows only runner-local bootstrap-key creation:
1 add, 0 change, 0 destroy, with both disks, server and bootstrap no-op.
Independent review found no cloud-safety blockers. PR #29 merged at 22:31:46,
main `0090db676933081036a2b0a67d9804ea8ce67220`; deployment `39075443591`
succeeded with the VM still stopped and the original disk still attached.


## Attachment cutover — completed 2026-10-17

- PR #30 merged at 22:39:39, main `d0090a779ea95e23ccc688a4798f759401b3e24a`.
- Final refreshed plan: local bootstrap-key creation plus one in-place server
  update changing only storage_devices; no disk/server replacement, root,
  bootstrap, user-data or backup-policy changes.
- Provider detached original data, attached the replacement at virtio:1, and
  started the VM. Root remains `01da1960-0299-4fef-8739-2bfb10aad259` at virtio:0.
- Initial deploy `39075974339` completed the cloud operation but reported an
  inconsistent computed `.host` value (stopped host 0 versus running physical
  host). Refreshed main plan had no cloud changes; retry attempt 2 succeeded.
- Boot journal at 22:41:06 confirms automatic ext4 growth to 50 GiB.
  `/data` reports 52,655,996,928 filesystem bytes, with about 36.2 GB available.
  Label `data` and UUID `9e4a70f4-bf84-431b-8842-9fd92eef5817` are unchanged.
- SSH verified at 22:41:57; writers were stopped beginning about 22:19
  (quiesced manifest 22:20:41). PostgreSQL was explicitly restarted afterward
  because its intentional pre-maintenance stop persists across boot.
- Eight repository heads/statuses and all captured uncommitted-file hashes,
  modes and owners exactly match the quiesced baseline. Directory metadata
  matches. Six Codex and two LifeData SQLite databases pass quick_check.
- All 324 baseline Codex thread IDs survive; post-boot count 325. An existing
  remote conversation was read successfully through the desktop connector.
- Docker root remains /data/docker. Previously running surf-atlas-postgres-1
  is healthy; the two previously stopped containers remain stopped. PostgreSQL
  opens postgres, surf_atlas_dev and surf_atlas_test with expected schema counts
  0/8/8; representative live tables contain rows.
- LifeData Python counts match: atlas 35, roam 11094, session 519. LiveView
  returns HTTP 200. Both HTTPS units and comin are active. Tailscale retains
  its node ID, DNS name and 100.103.219.13 address.
- API confirms replacement 50 GB Standard attached, original 20 GB MaxIOPS
  detached, and Simple Backup still disabled. The new data disk and root have
  no individual backup rules; original Flexible daily/7/0900 remains on the
  detached legacy disk only.

## Backup and recovery checkpoint

Stage D enables server Simple Backup Week at 0900 UTC in a separate apply.
The first scheduled cycle after activation is expected 2026-10-18 09:00 UTC
(02:00 PDT). A completed root/data backup and isolated full-filesystem and
application restore remain required; activation or a backup listing is not
completion. Preserve the old disk, fresh stopped snapshot, tested preflight
clone and helper until this checkpoint passes. Cleanup is a separate itemized
proposal and must preserve the active recovery policy.
