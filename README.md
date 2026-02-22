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

## CI/CD

- **PR opened** → `preview.yml` runs `tofu plan` on changed stacks, comments on PR
- **PR merged to main** → `deploy.yml` runs `tofu apply` on changed stacks

State locking uses native S3 conditional writes (`use_lockfile = true`), no DynamoDB needed.

### Required GitHub Secrets

| Secret | Description |
|---|---|
| `HCLOUD_TOKEN` | Hetzner Cloud API token |
| `AWS_ACCESS_KEY_ID` | From bootstrap output |
| `AWS_SECRET_ACCESS_KEY` | From bootstrap output |
| `ROUTE53_ZONE_ID` | Route 53 hosted zone ID for matz.io |

### Branch Protection

`main` requires PR with approval before merge. Deploy runs automatically on merge.

## Local Development

```bash
# Use the matz-infra AWS profile for local runs
cd stacks/hetzner-primary
tofu init
tofu plan -var="aws_profile=matz-infra" -var="hcloud_token=..." -var="route53_zone_id=..." -var="domain=matz.io"
```

## Cost

- Hetzner CAX31: ~€8/mo
- S3 state bucket: ~$0.01/mo
- Route 53: ~$0.50/zone/mo
