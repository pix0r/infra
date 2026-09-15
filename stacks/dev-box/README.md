# dev-box — NixOS box for Claude Code + Elixir, deployed from git

One small Hetzner server (default **cpx22**, 2 vCPU / 4 GB, Ashburn, ~USD 23/mo)
plus a persistent volume. US on purpose: EU is 5x cheaper but ~150 ms from California,
and this box is interactive. Provider choice is under review (brain: hosting-provider-eval-2026). **Two layers, two loops:**

| Layer | Owned by | Change it by |
|---|---|---|
| Server, volume, firewall, SSH keys | `stacks/dev-box/*.tf` | PR → merge → `deploy.yml` runs `tofu apply` |
| Everything on the box (users, packages, tmux, docker, services) | `hosts/dev-box/*.nix` at the repo root | PR → merge → **comin on the box** pulls main and `nixos-rebuild switch`es (~1 min) |

The server is cattle: replace it any time. `/data` (home dirs, repos, docker) is a
Hetzner volume that survives replacement and `enabled = false`.

## Costs (2026-09, excl. VAT, hourly-billed)

| Item | Monthly |
|---|---|
| cpx22 server (ash) | ~USD 23 |
| 20 GB volume | ~USD 1.3 |
| IPv4 | ~USD 0.6 |
| **Total** | **~USD 25** |

cpx32 (4 vCPU / 8 GB) is ~USD 42 if 4 GB is too tight for Elixir builds. EU cx33 (4/8)
would be ~EUR 10 all-in but ~150 ms away; cx*/cax* types are EU-only.

## What you need

| Credential | Where | Used for |
|---|---|---|
| `TF_VAR_hcloud_token` (Read & Write) | `secrets/terraform.env` (SOPS) | server, volume, firewall, keys |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | `secrets/terraform.env` (SOPS) | S3 state only |
| GitHub public keys | `hosts/dev-box/configuration.nix` (`sshKeys`) and Hetzner (`ssh.tf`) | SSH as `dev` / `root` |

On the box, after first SSH: `claude` (device-code login) and `gh auth login --with-token`
with a fine-grained PAT scoped to the repos you clone. Nothing else. No AWS creds, no
age key, no laptop keys. This repo is public, so comin needs no token.

## First boot (what happens, ~10 min)

1. `tofu apply` creates volume → server (Ubuntu) → attaches volume.
2. cloud-init waits for the volume, labels its filesystem `data`, runs **nixos-infect**
   (pinned commit, `var.nixos_infect_ref`) with a bootstrap `host.nix`, reboots into NixOS.
3. On that boot a one-shot `flake-bootstrap` unit runs
   `nixos-rebuild boot --flake github:pix0r/infra#dev-box` and reboots.
4. Now the flake config is live: `dev` user with home on `/data`, tmux, docker, comin.
   comin polls `main` every 60 s from here on.

Watch it: `ssh root@<ip> tail -f /tmp/infect.log`, then after the first reboot
`ssh root@<ip> journalctl -fu flake-bootstrap`, then `ssh dev@<ip>`.

## Day to day

- **Change the box:** edit `hosts/dev-box/configuration.nix`, PR (CI evaluates the
  flake), merge. `ssh dev@<ip> journalctl -u comin -f` shows the switch.
- **Add an Elixir app:** put the release under `/data/apps/<name>`, uncomment and adapt
  the `systemd.services` pattern in `configuration.nix`.
- **Bump nixpkgs:** `nix flake update` (Docker: see below), commit `flake.lock`.
- **Turn off:** PR with `enabled = false` in `variables.tf`, merge. Volume stays.
- **Turn on:** flip back. New server, same `/data`, same home dir.
- **Rebuild from scratch:** any change to `cloud-init/` replaces the server (the plan
  says "must be replaced"). `/data` is untouched.

## Working without installing nix or tofu on the laptop

```bash
# validate the flake (from repo root; in a git *worktree* copy flake.nix + hosts/ to a
# scratch dir first — the worktree's .git pointer is not visible inside the container)
docker run --rm -v "$PWD":/w -w /w nixos/nix:latest \
  nix --extra-experimental-features "nix-command flakes" \
  eval --raw .#nixosConfigurations.dev-box.config.system.build.toplevel.drvPath

# update inputs
docker run --rm -v "$PWD":/w -w /w nixos/nix:latest \
  nix --extra-experimental-features "nix-command flakes" flake update

# tofu (from stacks/dev-box); the backend block is Terramate-generated in CI —
# write it once locally as _terramate_generated_backend.tf (gitignored), see git history
tofu() { docker run --rm -it -v "$PWD":/work -w /work \
  -e TF_VAR_hcloud_token -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_REGION=us-east-1 \
  ghcr.io/opentofu/opentofu:1.9.0 "$@"; }
sops exec-env ../../secrets/terraform.env 'tofu plan'
```

## Gotchas

- `hosts/dev-box/hardware.nix` hard-codes Hetzner x86 layout (BIOS, `/dev/sda1`); cpx* and
  cx* both fit. A cax* (ARM) box or another provider needs a different hardware.nix.
- The volume has `prevent_destroy` + Hetzner delete protection. Removing it is a
  deliberate two-step (drop both, apply).
- If the flake fails to build on the box, comin keeps the last good generation; fix
  forward on main. If the *bootstrap* fails, `tofu apply -replace=hcloud_server.dev_box[0]`.
- `system.stateVersion` stays `26.05` forever; bumping nixpkgs is `flake.lock`.
