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

## Optional online expansion

The configured capacity remains 20 GB. If the normal working set needs more
room after cleanup, change `data_size` in `variables.tf`, for example to 50 GB,
through a reviewed PR. UpCloud permits growing an attached volume online, but
it cannot be shrunk in place. Keep `prevent_destroy`, the storage tier, backup
retention, and resource identity intact. Do not edit cloud-init to resize an
existing volume; changing it replaces the server in this stack.

Before applying, verify a current usable backup and inspect the Terraform plan.
The intended change is an in-place update to `upcloud_storage.data.size` with no
server replacement or reinstall. Resolve unexpected drift before merging.

After Terraform applies, verify that the backing device actually grew, then
expand the filesystem on the running host:

```bash
findmnt -no SOURCE,FSTYPE /data
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
sudo resize2fs /dev/disk/by-label/data
df -h /data
```

There is no partition on this data device, so no `growpart` step is needed.
`fileSystems."/data".autoResize` handles growth when the filesystem is mounted
again, such as at boot. A comin switch is not a substitute for the live
`resize2fs` step: comin and Terraform deploy independently and `/data` is already
mounted. Keep the provider's separate `filesystem_autoresize` operation off;
it requires the attached server to be stopped.

### Cost of retaining seven backups

At published USD rates checked on 2026-10-17, MaxIOPS is $0.25/GB/month and
each flexible backup is $0.06/GB/month based on the copied volume's size.
With this stack's seven retained daily backups, a 20 to 50 GB expansion adds
approximately $7.50/month of live storage and $12.60/month of backups, or
**$20.10/month** once all seven backups have the new size. These estimates
exclude taxes and temporary additional backups; verify account pricing before
applying. Cleanup alone does not incur that expansion cost.

## References

- [Cargo clean](https://doc.rust-lang.org/cargo/commands/cargo-clean.html)
- [Docker disk usage](https://docs.docker.com/reference/cli/docker/system/df/)
- [Docker image pruning](https://docs.docker.com/reference/cli/docker/image/prune/)
- [UpCloud online storage resize](https://upcloud.com/docs/products/cloud-servers/resizing/)
- [UpCloud storage API](https://developers.upcloud.com/1.3/9-storages/)
- [UpCloud pricing](https://upcloud.com/global/pricing/)
- [UpCloud backups and billing](https://upcloud.com/docs/guides/taking-backups/)
