# Recovering space on dev-box

`/data` is an ext4 filesystem on the whole persistent UpCloud device labeled
`data`. It holds `/data/home/dev`, `/data/docker`, `/data/lifedata`, and Tailscale
state. The separate root disk holds the Nix store. Run these commands over SSH
as `dev`; `sudo` is needed only for inspecting other users' data or the device.

## Restore capacity before resetting applications

On 2026-10-17 the 20 GB volume filled and Codex could not read thread metadata
(`SQLITE_IOERR_SHMSIZE`, code 4874). The measured usage was 9.1 GB under Docker
and 8.8 GB under home directories. Outliner alone had two confirmed generated
Rust target directories totaling about 5.7 GB. This establishes a cleanup
opportunity; it does not establish that all Docker data is disposable.

Inspect the current usage before cleaning:

```bash
df -h /data
sudo du -xhd1 /data | sort -h
du -sh "$HOME/outliner/target" "$HOME/outliner/src-tauri/target"
docker system df -v
```

Stop Outliner builds/watchers that use these target directories, then remove
only the confirmed generated output:

```bash
rm -rf -- "$HOME/outliner/target" "$HOME/outliner/src-tauri/target"
df -h /data
```

Keep `src-tauri` itself, source files, and Cargo lockfiles. The next build
recreates the target directories and takes longer. If using Cargo from the
project's development environment, `cargo clean --target-dir <absolute-path>`
is the equivalent target cleanup; `--dry-run` previews it.

Once `/data` has space, retry the failed Codex conversation. If it still fails,
inspect application logs before restarting the affected backend. Do not delete
the Codex database, its WAL files, or session history to fix a capacity issue.

## Inspect Docker separately

The incident's Docker output reported approximately 5.05 GB of reclaimable
images but only 815 KB of reclaimable build cache. Image and cache storage can
share layers, so their reported sizes are not additive.

```bash
docker system df -v
docker image ls --filter dangling=true
```

After confirming the listed dangling images can be rebuilt or pulled again,
`docker image prune` removes that narrow class and prompts before proceeding.
`docker image prune -a` also removes unused tagged images; make that a separate
decision after inspecting them. Avoid blanket system or volume pruning: the
host has persistent application volumes and stopped containers may hold state.

Nix garbage collection frees root-disk space, not this `/data` volume. Repeated
full builds can consume the recovered space again. Review Outliner's two target
locations and choose a consistent build location before adding automated
deletion. Changes to build profiles or cache placement belong in that project.

## Storage migration and disaster recovery

The current 20 GB MaxIOPS disk is retained at its original settings with
`prevent_destroy`. Desired replacement settings must never change that resource.
See [the staged migration and recovery runbook](storage-migration.md) for the
50 GB Standard replacement, reviewed attachment cutover, Simple Backup Week,
isolated restore proof, actual account billing and rollback procedure.

Do not change the old disk's tier or remove destruction protection to accomplish
this migration. Do not change cloud-init or disko to resize it. A block clone
preserves the existing ext4 UUID/label, ownership and Docker metadata; the NixOS
mount's `autoResize` grows ext4 on the new 50 GB backing device at boot.

For an independently reviewed future in-place expansion on the running host,
verify the device's new size first, then run
`sudo resize2fs /dev/disk/by-label/data`. There is no data partition, so no
`growpart` step is needed. A comin switch does not resize an already-mounted
filesystem. Keep UpCloud's separate `filesystem_autoresize` operation disabled.

Scheduled snapshots are crash-consistent. Recovery requires a tested clone and
application/database checks, not just an online entry in a backup listing.
Deleting the VM through `enabled=false` also deletes its root disk and ends
Simple Backup rotation; retained copies become separately billed on-demand
backups until deliberately deleted.

## References

- [Cargo clean](https://doc.rust-lang.org/cargo/commands/cargo-clean.html)
- [Docker disk usage](https://docs.docker.com/reference/cli/docker/system/df/)
- [Docker image pruning](https://docs.docker.com/reference/cli/docker/image/prune/)
- [UpCloud online storage resize](https://upcloud.com/docs/products/cloud-servers/resizing/)
- [UpCloud storage API](https://developers.upcloud.com/1.3/9-storages/)
- [UpCloud pricing](https://upcloud.com/global/pricing/)
- [UpCloud backups and billing](https://upcloud.com/docs/guides/taking-backups/)
