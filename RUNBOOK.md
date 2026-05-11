# Cattle drill — pix0r/infra k3s + Flux primary

The operational sequence to stand up `primary` from zero, plus the destroy/recreate drill that proves cattle, not pets.

## One-time prerequisites (before first apply)

These are manual steps Mike runs before the very first `tofu apply` of the new
shape. After that, every rebuild is reproducible.

### 1. SOPS age key on this machine

```bash
# direnv should already load this from .envrc
export SOPS_AGE_KEY_FILE=$HOME/code/_FY/assistant/linode-setup/secrets/age-key.txt
echo "$SOPS_AGE_KEY_FILE"  # sanity
sops -d secrets/terraform.env | head -3  # confirms decryption works
```

If decryption fails, the key is somewhere else — update `.envrc` and re-`direnv allow`.

### 2. GitHub PAT for Flux bootstrap

Flux's `flux bootstrap github` needs a token that can push to `pix0r/infra` (so
it can commit its own `clusters/primary/flux-system/` manifests on first run).

- Go to <https://github.com/settings/tokens?type=beta>
- Click **Generate new token** → **Fine-grained personal access token**
- **Resource owner**: `pix0r`
- **Repository access**: Only select repositories → `pix0r/infra`
  (optionally also `pix0r/brain-orchestrator` for Sprint 2)
- **Repository permissions**:
  - **Contents**: Read and write (Flux commits manifests)
  - **Metadata**: Read-only (automatically required)
  - **Administration**: Read and write (Flux installs a deploy key)
- **Expiration**: 90 days (or longer; rotate quarterly)
- Generate → copy the `github_pat_...` value once.

Add it to SOPS:

```bash
sops secrets/terraform.env
# Append:
#   TF_VAR_flux_github_pat=github_pat_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Save + close (sops re-encrypts on close).
git add secrets/terraform.env
git commit -m "secrets: add TF_VAR_flux_github_pat for Flux bootstrap"
```

### 3. Route 53 hosted zone ID in the ClusterIssuer

The cluster-issuer manifest at
`clusters/primary/infrastructure/cert-manager/cluster-issuer.yaml` has
`hostedZoneID: REPLACE_ME_ROUTE53_ZONE_ID`. Pull the real ID from
`secrets/terraform.env` (look at `TF_VAR_route53_zone_id`) and commit.

### 4. AWS IAM creds for cert-manager DNS-01

The `route53-credentials` Secret at
`clusters/primary/infrastructure/cert-manager-route53-creds/secret.enc.yaml`
ships with `REPLACE_ME_*` placeholders. Create (or reuse) an IAM user scoped to:

- `route53:GetChange`
- `route53:ChangeResourceRecordSets` (on the matz.io hosted zone ARN only)
- `route53:ListHostedZonesByName`

Fill in real creds, then encrypt in place:

```bash
$EDITOR clusters/primary/infrastructure/cert-manager-route53-creds/secret.enc.yaml
sops -e -i clusters/primary/infrastructure/cert-manager-route53-creds/secret.enc.yaml
```

The `.sops.yaml` rule for `clusters/.*\.enc\.yaml` encrypts only
`stringData`/`data` so the resource name/namespace stay readable to Kustomize.

### 5. Weave GitOps admin password

```bash
PASS=$(openssl rand -base64 24)
HASH=$(htpasswd -bnBC 10 "" "$PASS" | tr -d ':\n' | sed 's/$2y/$2a/')
echo "Dashboard password (save in 1Password): $PASS"
echo "Bcrypt hash: $HASH"
$EDITOR clusters/primary/infrastructure/weave-gitops/admin-secret.yaml
# Paste $HASH as password. Rename file:
mv clusters/primary/infrastructure/weave-gitops/admin-secret.yaml \
   clusters/primary/infrastructure/weave-gitops/admin-secret.enc.yaml
sops -e -i clusters/primary/infrastructure/weave-gitops/admin-secret.enc.yaml
# Update the kustomization.yaml in that dir to reference the new filename.
```

### 6. Install the cluster's SOPS age key after Flux bootstrap

Flux's SOPS decryption needs a `sops-age` Secret in the `flux-system` namespace
containing the same age private key the `.sops.yaml` `creation_rules` use. This
isn't part of `flux bootstrap`, so it's a post-bootstrap one-liner. The
`RUNBOOK` step `Watch and wait` below tells you when to run it.

## Sprint 1 apply

From the worktree (or from `_FY/infra` directly after merging):

```bash
cd stacks/hetzner-primary
sops exec-env ../../secrets/terraform.env 'tofu init'
sops exec-env ../../secrets/terraform.env 'tofu apply'
```

### Watch and wait

```bash
# Discover the IP
IP=$(tofu output -raw server_ipv4)
KEY=$(tofu output -raw ssh_private_key)

# Cloud-init runs ~5-10 min. Sentinel:
ssh -i "$KEY" root@$IP 'while ! test -f /var/log/cloud-init-complete; do sleep 5; done; echo done'

# Once cloud-init is done, install the cluster age key (one-time per cluster):
ssh -i "$KEY" root@$IP "kubectl -n flux-system create secret generic sops-age \
  --from-file=age.agekey=/dev/stdin" < "$SOPS_AGE_KEY_FILE"

# Watch Flux reconcile (~5-10 min for cert-manager + LE cert issuance):
ssh -i "$KEY" root@$IP 'flux get all -A'
# Repeat until every Kustomization is READY=True.
```

### Smoke test

```bash
# Hello-world over Let's Encrypt prod cert
curl -I https://app.matz.io
# Expected: HTTP/2 200, Server: nginx, valid cert

# Weave GitOps dashboard (basic auth: admin / $PASS from step 5)
curl -I https://weave.app.matz.io
# Expected: HTTP/2 401 (auth challenge) on first hit
```

## The drill — destroy + recreate

```bash
cd stacks/hetzner-primary
sops exec-env ../../secrets/terraform.env 'tofu destroy'
# Wait for completion (~2 min)

sops exec-env ../../secrets/terraform.env 'tofu apply'
# Repeat the Watch and wait + Smoke test steps above.
# Target: green within 30 min from `apply` press.
```

If the drill passes, Sprint 1 is done. Sprint 2 (brain-orchestrator HelmRelease)
can start.

## Known gotchas

- **Cloud-init logs leak the Flux PAT.** It's interpolated into
  `/var/lib/cloud/instance/user-data.txt` and `/var/log/cloud-init-output.log`
  in plaintext. Acceptable for a single-tenant box; rotate the PAT quarterly.
  Fix later: move to a one-shot script that consumes the PAT from a tempfile
  and shreds it.
- **k3s default ingress is Traefik v2.** All `Ingress` resources use
  `ingressClassName: traefik`.
- **Let's Encrypt rate limits.** 50 certs/week per registered domain. The
  destroy/recreate drill burns 2 certs per loop (`app.matz.io`,
  `weave.app.matz.io`). Use the LE staging issuer for repeat testing if you
  hammer this.
- **Weave GitOps version pin.** Chart `4.0.x` works against Flux v2.4+. If
  `flux bootstrap` installs a newer Flux, bump the chart pin.
