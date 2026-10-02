# Legacy Linode migration findings and scope

Recorded on 2026-10-02. This project inventories the legacy Linode server
`epic3`, preserves data worth keeping, and moves needed services into the
infrastructure managed by this repository. Mike no longer uses Jenkins or
actively maintains this server. The first priorities are restoring disk space,
setting up `mike.pixor.net` as a Bluesky handle, and moving `pixor.net` DNS to
AWS Route 53 so personal email no longer depends on the legacy server.

This is the initial migration brief, not an approval to retire every service
discovered on the host. The [migration plan](../../superpowers/plans/2026-10-02-legacy-linode-migration.md)
defines the remaining inventory, DNS cutover, application moves, and retirement
checks. Target application placement remains to be decided after inventory.

## Current project status

| Item | Status |
| --- | --- |
| Worktree | `.claude/worktrees/legacy-migration`, branch `migration/legacy-linode`, based on locally fetched `origin/main` at `2a85404` |
| Jenkins log cleanup | Confirmed: log is empty; root filesystem has 36 GB available and is 55% used |
| Jenkins boot configuration | Confirmed disabled; not listed among running services in the latest check |
| Bluesky TXT record | Candidate prepared and validated; live publication still needs verification |
| Route 53 migration | Planned; no hosted zone or delegation change created by this project |
| Full service and data inventory | Initial read-only pass complete; privileged and application-level inventory outstanding |

## DNS and email findings

| Component | Observed configuration |
| --- | --- |
| Registrar | Amazon Registrar, Inc., from [registry RDAP](https://rdap.verisign.com/net/v1/domain/pixor.net) |
| Nameserver name | `ns1.pixor.net` → `45.79.94.199` |
| Nameserver name | `ns2.pixor.net` → `23.239.7.131` |
| Physical redundancy | None established: both IPv4 addresses are assigned to `epic3`'s `eth0` interface, and BIND listens on both |
| Operating system | Ubuntu 16.04.7 LTS, verified over SSH |
| DNS software | Both public DNS endpoints advertise BIND `9.10.3-P4-Ubuntu` |
| Zone source | `/etc/bind/master/pixor.net`, loaded as a master zone through `/etc/bind/named.conf.local.master` |
| Management | Flat BIND files and shell helpers in a Git repo at `/etc/bind`; no `pixor.net` stack in this infra repo |
| Git state | Initial inspection showed `MM master/pixor.net`; Mike subsequently reported a clean working tree. Existing Git history is the zone rollback source |
| Initial SOA serial | `2021102501` on both public addresses |
| Zone default TTL | 600 seconds |
| Parent delegation TTL | `.net` referral shows 172800 seconds, or 48 hours |
| DNSSEC | No DS record observed at the parent; recheck before cutover |
| Personal email | Apex MX records point to Fastmail: priorities 10 and 20 for `in1-smtp.messagingengine.com.` and `in2-smtp.messagingengine.com.` |
| SPF | Apex TXT: `v=spf1 include:spf.messagingengine.com ?all` |
| DKIM | `fm1`, `fm2`, and `fm3` under `_domainkey` point to Fastmail's `dkim.fmhosted.com` names |
| DMARC | No valid DMARC policy observed: `_dmarc.pixor.net` returns a wildcard Keybase TXT value |

Amazon registration does not imply Route 53 DNS hosting. The personal AWS
profile `matz-infra` returned zones for `flyingyeti.com`, `powderjunkieapp.com`,
`myrisinglegacy.com`, `wolfpackcycling.org`, `matz.io`, and
`matzlearningsolutions.com`, but none for `pixor.net`. This does not establish
whether another AWS account contains an unused zone.

Fastmail hosts the standard `mike@pixor.net` mailbox according to its DNS
routing. Email delivery and authentication still depend on `epic3` answering
DNS. The same zone also contains wildcard MX records and explicit legacy
subdomain MX records; preserve these until their consumers are identified.

The Keybase TXT record is attached to the wildcard owner in the BIND file by
owner-name inheritance. It currently appears in TXT answers for missing names,
including `_atproto.mike.pixor.net`; it is not an AT Protocol proof.

## DNS evidence

The [original zone snapshot](evidence/pixor.net.before-atproto.zone) is a
byte-for-byte copy of the readable zone file, including comments and legacy
records. SHA-256:

```text
bdb390dee5d8f29fd790f431744bc7d3d1d7307a8a5ddf4729b22f7c6492aa81
```

The [proposed handle zone](evidence/pixor.net.with-atproto.zone) changes the
serial to `2026100201` and adds one TXT record. `named-checkzone` on `epic3`
reported `OK`. SHA-256:

```text
f4f72be7ce133ef9a96de419a3996e70d9a71d81a8a3a6e33cf11affc147b116
```

These are dated evidence, not the eventual desired Route 53 configuration.
Refresh the export after publishing the handle and before DNS cutover.

## Jenkins and disk findings

Before cleanup, `/dev/root` was 79 GB with zero available space.
`/var/log/jenkins` occupied 38 GB; the active `jenkins.log` was
38,911,541,248 bytes, approximately 36.24 GiB. `jenkins.log.1` was 807 MB.
All 255 dated `.backup` files together occupied only 12.26 MiB.

The rotation rule already contained `size 100M`, `copytruncate`, `rotate 52`,
`compress`, and `delaycompress`. Copying such a large active log on a full disk
is a likely obstacle to rotation, not a confirmed explanation for the original
log growth. The log tail contained repeated DNS question diagnostics. The
rotation state file `/var/lib/logrotate/status` was empty.

A later check confirmed the active log was truncated to zero and the root
filesystem was 55% used, with 36 GB available. Jenkins is disabled. Its
approximately 1.3 GB home at `/var/lib/jenkins` remains a candidate for archival
review; do not confuse log cleanup with deletion of jobs or configuration.

## Initial service and data inventory

The following were observed over SSH as `mike`; inaccessible directories were
excluded from the size scan. Sizes are lower bounds where permissions prevent
a complete read, especially for databases and mail stores. Installed or running
software does not establish that an application is still needed.

| Area | Observation | Next check |
| --- | --- | --- |
| Web | Apache is running; listeners on 80 and 443; `/var/www` reports 9.6 GB across many domain directories | Export vhosts, map domains to document roots and runtimes, check access activity |
| Database | MySQL is running and listens on all IPv4 addresses at port 3306 | Privileged database inventory, consumers, consistent dumps, restore test; external firewall exposure not tested |
| Legacy mail | Postfix and Dovecot are running; listeners include 25, 110, 143, 993, and 995 | Inventory domains, mailboxes, aliases, forwards, queues, and application SMTP before retirement |
| Git hosting | `/var/lib/gitolite` reports 441 MB | Enumerate repositories and consumers; archive or migrate |
| Subversion | `/opt/svn` reports 2.4 GB | Enumerate repositories, history, and consumers; archive or migrate |
| Monitoring | `munin-node` is running with a listener on 4949 | Identify monitoring clients and decide whether it is still used |
| Automation | `cron` and `atd` are running | Root/user crontabs, `/etc/cron.*`, timers, deferred jobs, backup destinations |
| User data | `/home` reports 4.0 GB, mostly `/home/mike` | Review retained files and private archives without committing secrets |
| DNS domains | Dozens of files exist in `/etc/bind/master`, including domains now using AWS | Determine actual delegation and ownership for each; a zone file alone does not mean this server is authoritative publicly |

Larger visible web trees include `matzfamily.net` (2.0 GB), `pixor.net` (1.6 GB),
and `mikematz.net` (1.2 GB). There are also web directories for
`code.pixor.net`, `huginn.pixor.net`, `flyingyeti.com`, and many older projects.
Database directories for PostgreSQL and application directories for Redmine
exist; runtime use and data content have not been established.

## Existing target infrastructure

This repository uses Terramate and OpenTofu for infrastructure, S3 state, and
SOPS-encrypted credentials. `hosts/dev-box` provides the NixOS configuration
with comin deploying from `main`, Docker storage on persistent `/data`, and
Tailscale access. `stacks/upcloud-dev-box` describes the current dev box.
`stacks/hetzner-primary` describes Coolify, Forgejo, and application hosting
but is documented as paused. Neither is automatically the destination for
every legacy production application.

The proposed DNS destination is a dedicated `stacks/pixor-dns` stack, separate
from compute replacement. The checked-in `matz-infra-tofu` policy allows
existing record management but omits hosted-zone creation/deletion and
Route 53 Domains registration operations. Plan zone bootstrap and registrar
access explicitly; do not assume the existing CI identity can perform them.

## Migration decisions and constraints

- Preserve `mike@pixor.net` delivery and existing mail authentication records.
- Set the existing `flyingyeti.com` Bluesky account's handle to `mike.pixor.net`.
- Include the handle TXT record in the later Route 53 migration.
- Separate DNS cutover from website/database moves; keep current targets during the first DNS migration.
- Identify and back up remaining workloads before deleting data or retiring `epic3`.
- Preserve existing BIND working-tree changes and use committed history for zone rollback; no extra zone backup is needed. Do not run its serial helper, which hardcodes an old serial.
- Keep credentials, database dumps, mail archives, private keys, and raw private configurations out of Git; use SOPS or protected backup storage.
- Apply the repository's TDD requirement to any new conversion tooling or infrastructure implementation. Today's artifacts are documentation and DNS data snapshots.

## Outstanding questions

- Which hosted applications and repositories should be retained, archived, or retired?
- Are any legacy mailboxes, mailing lists, or SMTP clients still dependent on Postfix/Dovecot?
- Which other registered domains still delegate to these nameservers?
- Which AWS identity owns the Amazon registration and can create the new hosted zone?
- Should retained production workloads use the paused Hetzner app stack, a separate NixOS host, or another target?
- Where should backups live, and what retention and restore checks should each dataset have?
