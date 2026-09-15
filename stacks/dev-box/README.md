# dev-box — disposable Claude Code box on Hetzner

One small Ubuntu server for running Claude Code (and the brain orchestrator) unattended,
off the laptop. SSH in only. Created and destroyed through git so there is a durable
record of every box.

**Not** the k3s + Flux `primary` substrate (that's `stacks/hetzner-primary`, PR #6).
This stack has no DNS, no ingress, no cluster. Retire it when `primary` exists.

## What you need

| Credential | Where | Used for |
|---|---|---|
| `TF_VAR_hcloud_token` | `secrets/terraform.env` (SOPS) | creating the server, firewall, SSH keys |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | `secrets/terraform.env` (SOPS) | S3 state bucket only |
| GitHub public keys | `https://github.com/<github_user>.keys` | SSH auth for `root` and `dev` |

The Hetzner token must be **Read & Write**. On the box itself, only two credentials are
ever added, both after first SSH: the Claude login (device-code flow) and a fine-grained
GitHub token scoped to the repos you clone. No AWS creds, no age key, no laptop keys.

## Turn on / turn off

`var.enabled` (default `true`) controls whether the server exists. Firewall and SSH keys
are free and stay either way.

- **On:** merge a PR with `enabled = true` → `deploy.yml` applies → server exists.
- **Off:** merge a PR flipping `enabled = false` → `deploy.yml` destroys the server.

Hourly billing stops at delete. Powering off does not stop billing.

Change the default in `variables.tf` in the PR. Do not use a local `terraform.tfvars`
(gitignored): the committed default is the durable record of whether a box exists.

## Apply

**Via CI (default path, no local tooling):** open a PR, read the plan comment from
`preview.yml`, merge. `deploy.yml` runs `tofu apply` on the changed stack. The server IP
is in the job's apply output (`ssh_command`).

**Locally, without installing tofu** (Docker only; the image is pinned to the version in
`.tool-versions`):

```bash
cd stacks/dev-box
tofu() { docker run --rm -it -v "$PWD":/work -w /work \
  -e TF_VAR_hcloud_token -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_REGION=us-east-1 \
  ghcr.io/opentofu/opentofu:1.9.0 "$@"; }
# backend block is Terramate-generated; without terramate installed, write it once:
cat > _terramate_generated_backend.tf <<'HCL'
terraform {
  backend "s3" {
    bucket       = "matz-infra-tfstate"
    key          = "stacks/fce6041a-e277-40fd-9601-c31d876f1825/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
HCL
sops exec-env ../../secrets/terraform.env 'tofu init'
sops exec-env ../../secrets/terraform.env 'tofu plan'
sops exec-env ../../secrets/terraform.env 'tofu apply'
tofu output
```

The generated backend file is gitignored (`_terramate_generated_*`) and matches what
`terramate generate` produces from `generate.tm.hcl`, so CI and local share state.

## First SSH

cloud-init takes ~3–5 minutes after the server is up.

```bash
ssh dev@<ipv4>
ls ~/CLOUD-INIT-DONE          # exists when cloud-init finished
tmux
claude                        # device-code login in your browser
gh auth login --with-token    # paste a fine-grained PAT: pix0r/brain + pix0r/brain-orchestrator, Contents RW
gh auth setup-git
git clone --recurse-submodules https://github.com/pix0r/brain ~/brain
```

For the orchestrator on the box: `claude setup-token`, put it in the orchestrator env
file per `apps/orchestrator/rel/README.md`, then `brain start`. Reach the UI with the
`orchestrator_tunnel_command` output (`ssh -N -L 4000:localhost:4000 dev@<ip>`) and open
<http://localhost:4000>.

## Done with it

Push your branches, then flip `enabled = false` and merge (or `tofu destroy` locally).
Rotate the GitHub PAT you minted for the box.

## Sizing

| Type | vCPU / RAM | ~EUR/mo | Note |
|---|---|---|---|
| cpx21 | 3 / 4 GB | 8 | fine for Claude sessions alone |
| **cpx31** (default) | 4 / 8 GB | 15 | Docker + orchestrator + a couple of sessions |
| cpx41 | 8 / 16 GB | 28 | if Elixir builds in Docker get slow |

x86 on purpose: it sidesteps any arm64 gaps in the orchestrator's Docker image, and ARM
(cax) availability in `ash` was not verified. The API rejects unavailable type/location
pairs at plan time, so a wrong guess fails loudly, not silently.
