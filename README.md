# infra

IaC for personal infrastructure on Hetzner Cloud, managed with Terramate + OpenTofu.

## Architecture

```
stacks/
├── tfstate-backend/     # S3 bucket + DynamoDB for remote state (bootstrap first)
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
- AWS credentials with Route 53 + S3 + DynamoDB access

## Bootstrap (one-time)

```bash
# 1. Bootstrap the state backend (uses local state)
cd stacks/tfstate-backend
tofu init
tofu apply -var="aws_profile=your-profile"

# 2. Now deploy everything else via PR workflow (or locally):
cd stacks/hetzner-primary
cp ../../terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars
tofu init
tofu plan
```

## CI/CD

- **PR opened** → `preview.yml` runs `tofu plan` on changed stacks, comments plan on PR
- **PR merged to main** → `deploy.yml` runs `tofu apply` on changed stacks

### Required GitHub Secrets

| Secret | Description |
|---|---|
| `HCLOUD_TOKEN` | Hetzner Cloud API token |
| `AWS_ACCESS_KEY_ID` | AWS access key (Route 53 + S3 state) |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `ROUTE53_ZONE_ID` | Route 53 hosted zone ID for matz.io |

### Branch Protection

- `main` branch requires PR with approval before merge
- Deploy workflow runs automatically on merge

## Cost

- Hetzner CAX31: ~€8/mo
- S3 state bucket: ~$0.01/mo
- DynamoDB (on-demand): ~$0/mo
- Route 53: ~$0.50/zone/mo
