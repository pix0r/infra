# dev-box migration execution record

Coordinator: Mike's Mac, public SSH/control-plane access. Times below are UTC.
No credentials, application content or private file manifests belong here.

## Readiness — completed 2026-10-17

- PR #28 merged at 22:10:45, main commit `1e17376844646dbe34f6edc1aecbb99e7a1402fe`.
- Terraform Deploy run `39073992333` succeeded. No cloud disk/server changes.
- Comin switch succeeded at 22:11:51; deployment `7ec0b20c-58cb-4f68-8375-6be60adcfffd`.
- Live system: `/nix/store/ybpvcc6ka674qayl4g6hn6r5l81fqqs9-nixos-system-dev-box-26.05.20260914.c3eea5b`.
- Live fstab: `/dev/disk/by-label/data /data ext4 x-systemd.growfs,x-initrd.mount 0 2`.
- Original ext4 disk remains 20 GB and attached. No production shutdown/cutover yet.

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

- B / PR #29: stopped snapshot, Standard clone, 50 GB growth, import and completed apply.
- C / PR #30: reviewed attachment-only apply, filesystem/data/application checks.
- D / PR #31: subsequent Simple Backup Week apply.
- E: completed scheduled root/data backups, isolated application recovery proof,
  then a separately reviewed itemized legacy/test-resource cleanup proposal.
