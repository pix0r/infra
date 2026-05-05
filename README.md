# infra

IaC for personal infrastructure on Hetzner Cloud, managed with Terramate + OpenTofu.

## Architecture

```
stacks/
├── tfstate-backend/     # S3 bucket + IAM user (bootstrap first, local state)
└── hetzner-primary/     # Primary server: Coolify + Forgejo + apps
```

| Service | URL |
|---|---|
| Forgejo (git) | `dev.matz.io` |
| Coolify (deploy) | `deploy.matz.io` |
| Apps (wildcard) | `*.app.matz.io` |

## Prerequisites

- [OpenTofu](https://opentofu.org/docs/intro/install/)
- [Terramate CLI](https://terramate.io/docs/cli/installation)
- [SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age) for secrets
- Hetzner Cloud API token
- AWS account with an admin/root user (for bootstrap only)

## Bootstrap (one-time)

The bootstrap stack creates the S3 state bucket and a scoped IAM user
for all future Tofu operations (Route 53 + S3 state). It uses local
state since it creates the remote backend itself.

```bash
# 1. Bootstrap with your existing AWS credentials (admin/root)
cd stacks/tfstate-backend
tofu init
tofu apply -var="aws_profile=your-admin-profile"

# 2. Grab the new credentials
tofu output -raw access_key_id
tofu output -raw secret_access_key

# 3. Add to ~/.aws/credentials
cat >> ~/.aws/credentials <<EOF
[matz-infra]
aws_access_key_id = <from step 2>
aws_secret_access_key = <from step 2>
EOF

# 4. Add GitHub repo secrets (Settings → Secrets → Actions):
#    AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, ROUTE53_ZONE_ID, HCLOUD_TOKEN

# 5. Delete your old tofu-route53 IAM user if you created one manually
```

After bootstrap, all infrastructure changes go through PRs.

## Secrets (single source: SOPS-encrypted file in repo)

All sensitive values live in `secrets/terraform.env`, encrypted with [SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age). The same encrypted file is consumed by both:

- **GitHub Actions** — decrypts using `SOPS_AGE_KEY` (the age private key, stored once as a repo secret) and exports values as env vars for Tofu
- **Local fast loop** — `sops exec-env` decrypts in memory and runs Tofu under the decrypted env

This means: **add or rotate a secret once via `sops`, both paths see the change**. No drift.

### One-time setup (operator)

```bash
# 1. Copy the template, fill in real values
cp secrets/terraform.env.example secrets/terraform.env
$EDITOR secrets/terraform.env  # paste real HCLOUD_TOKEN, AWS_*, ROUTE53_ZONE_ID

# 2. Encrypt in place
sops -e -i secrets/terraform.env

# 3. Commit + push the encrypted file (it's safe in git)
git add secrets/terraform.env
git commit -m "secrets: initial encrypted terraform.env"

# 4. Drop the age key into GitHub Actions (one-time per repo)
cat ~/.config/sops/age/keys.txt | gh secret set SOPS_AGE_KEY -R pix0r/infra
# (or wherever your age private key lives)
```

### Editing later

```bash
sops secrets/terraform.env   # opens decrypted in $EDITOR; re-encrypts on save
git add secrets/terraform.env && git commit -m "secrets: rotate HCLOUD_TOKEN"
```

## CI/CD

- **PR opened** → `preview.yml` decrypts secrets, runs `tofu plan` on changed stacks, comments plan on PR
- **PR merged to main** → `deploy.yml` decrypts secrets, runs `tofu apply` on changed stacks

State locking uses native S3 conditional writes (`use_lockfile = true`), no DynamoDB needed.

### Required GitHub Secret

| Secret | Description |
|---|---|
| `SOPS_AGE_KEY` | age private key — decrypts `secrets/terraform.env` |

(Previously: `HCLOUD_TOKEN`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `ROUTE53_ZONE_ID` were individual repo secrets. Those are now superseded by the single SOPS-encrypted file. **Delete them** from repo settings after this PR merges.)

### Branch Protection

`main` requires PR with approval before merge. Deploy runs automatically on merge.

## Local Development

**First-time setup**: copy the env template and tell `direnv` where your age private key lives:

```bash
cp .envrc.example .envrc
$EDITOR .envrc                 # set SOPS_AGE_KEY_FILE to your real path
direnv allow
```

`.envrc` is gitignored — it's per-machine state. After this, plain `sops` commands work in this repo without wrapping in `assist` or passing the key path each time.

### Day-to-day: plan + apply against any stack

The SOPS file holds everything Terraform needs (AWS scoped creds + `TF_VAR_*` for hcloud/route53/domain). One command per operation, no `-var=` clutter:

```bash
cd stacks/hetzner-primary
tofu init
sops exec-env ../../secrets/terraform.env 'tofu plan'
sops exec-env ../../secrets/terraform.env 'tofu apply'
```

**Note**: the command after the env file must be a single-quoted string — `sops exec-env` only takes two positional args (the file and the command). Bare `sops exec-env file tofu plan` would have SOPS try to decrypt `plan` as a second file and fail with `missing file to decrypt`. Wrap any multi-word command (with or without flags) in quotes.

`sops exec-env` decrypts in memory, exports the env vars, runs the wrapped command, and discards the decrypted env on exit. Same encrypted file the GHA workflows use — no drift between local and CI.

### Bootstrap is different

The `tfstate-backend` stack is a one-time setup that creates the IAM user whose creds end up *in* the SOPS file. By definition, those creds don't exist when bootstrap runs. So bootstrap uses your **interactive admin identity** (e.g., AWS SSO via Identity Center) instead of the SOPS file:

```bash
aws sso login --profile <your-admin-profile>
export AWS_PROFILE=<your-admin-profile>
cd stacks/tfstate-backend
tofu init
tofu apply
# Capture outputs:
tofu output -raw access_key_id        # → AWS_ACCESS_KEY_ID for SOPS
tofu output -raw secret_access_key    # → AWS_SECRET_ACCESS_KEY for SOPS
```

Then add those values to `secrets/terraform.env`, encrypt with `sops -e -i`, commit, push. From then on, every other operation uses the simple `sops exec-env` pattern above.

## Cost

- Hetzner CAX31: ~€8/mo
- S3 state bucket: ~$0.01/mo
- Route 53: ~$0.50/zone/mo
