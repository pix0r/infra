# infra-bootstrap

IaC bootstrap for Hetzner Cloud + Coolify + Forgejo, with Route 53 DNS.

## Prerequisites

- [OpenTofu](https://opentofu.org/docs/intro/install/) (`tofu` CLI)
- Hetzner Cloud account + API token
- AWS credentials with Route 53 access
- A domain with a Route 53 hosted zone

## Quick Start

```bash
# 1. Configure
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # fill in your values

# 2. Set AWS credentials (if not using ~/.aws/credentials)
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."

# 3. Deploy
tofu init
tofu plan
tofu apply

# 4. Wait ~5 min for cloud-init to finish, then:
tofu output ssh_command  # SSH into the server
tofu output coolify_url  # Open Coolify dashboard
tofu output forgejo_url  # Open Forgejo
```

## What Gets Created

- 1x Hetzner CAX31 (ARM, 8GB RAM, 4 vCPU) in Ashburn, VA
- Private network (10.0.0.0/16) for future multi-node
- Firewall (SSH + HTTP/S only)
- Docker + Coolify + Forgejo installed via cloud-init
- Route 53 DNS records for Coolify, Forgejo, and app wildcard
- SSH key pair generated and stored locally

## Architecture

```
                    ┌─────────────────────────────────┐
                    │  Hetzner CAX31 (primary)        │
Route 53 ──DNS──▶  │                                  │
                    │  ┌───────────┐  ┌────────────┐  │
                    │  │  Coolify  │  │  Forgejo   │  │
                    │  │  :443     │  │  :3000     │  │
                    │  └───────────┘  └────────────┘  │
                    │                                  │
                    │  ┌──────────────────────────┐   │
                    │  │  Your apps (Docker)      │   │
                    │  │  *.apps.domain.com       │   │
                    │  └──────────────────────────┘   │
                    └─────────────────────────────────┘
```

## Scaling

Add more servers by creating additional `hcloud_server` resources and registering them as Coolify worker nodes.

## Cost

~€8/mo for the CAX31. DNS via Route 53 is negligible (~$0.50/zone/mo).
