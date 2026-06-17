# Pipeline (GitLab CI)

Everything needed to run this Terraform project in GitLab CI lives in this
folder. The repository-root `.gitlab-ci.yml` is a one-line stub that `include`s
[`gitlab-ci.yml`](gitlab-ci.yml) from here.

```
pipeline/
├── gitlab-ci.yml                         # the actual pipeline (stages/jobs)
├── backend_override.tf.example           # -> ./backend_override.tf (local state)
├── backend-config.local.tfbackend.example# -> hand-run vs. the shared remote state
├── scripts/
│   ├── tf.ps1                            # local wrapper (Windows / PowerShell)
│   └── tf.sh                             # local wrapper (Linux / macOS)
└── README.md
```

## Pipeline flow

| Stage | Job | When | Needs Grid access |
|-------|-----|------|-------------------|
| validate | `fmt`, `validate` | every MR + default branch | no |
| plan | `plan` | every MR + default branch | **yes** |
| apply | `apply` | default branch only, **manual** | **yes** |

- State is **GitLab-managed HTTP state**, wired automatically by the
  `gitlab-terraform` wrapper in the official Terraform image. No backend
  secrets to manage.
- `plan` saves `plan.cache` as an artifact and publishes a Terraform report to
  the MR widget. `apply` consumes that exact plan — no drift between plan and
  apply.
- `apply` is **manual** and uses a `resource_group` so two applies never run
  against the shared state at once.

## Required CI/CD variables

Set these in **Project → Settings → CI/CD → Variables** (mask + protect the
secrets):

| Variable | Value | Flags |
|----------|-------|-------|
| `TF_VAR_infoblox_username` | NIOS WAPI username | Masked, Protected |
| `TF_VAR_infoblox_password` | NIOS WAPI password | Masked, Protected |
| `TF_VAR_infoblox_host` | Grid Manager host (optional; else from `terraform.tfvars`) | Protected |

Terraform reads `TF_VAR_*` automatically, so **no `credentials.auto.tfvars` is
needed in CI**. Non-secret config (host, views, `network_containers`) stays in
the committed `terraform.tfvars`.

> **Runner reachability:** the `plan` and `apply` jobs talk to the NIOS Grid
> Manager (WAPI). The GitLab runner must have network access to
> `infoblox_host`. Use a self-hosted runner on a network that can reach the
> Grid if it isn't publicly reachable.

## Per-environment state (optional)

To split state (e.g. dev vs prod), override `TF_STATE_NAME` per job/branch or
use GitLab `environment:` + parallel matrices. Each distinct `TF_STATE_NAME` is
an independent GitLab-managed state document.

---

## Running by hand

All hand-runs go through the wrappers, which always execute from the repo root.
Credentials come from `credentials.auto.tfvars` (see root README) or `TF_VAR_*`.

### Option A — offline, local state (quickest)

```powershell
# Windows / PowerShell
pwsh pipeline\scripts\tf.ps1 init-local
pwsh pipeline\scripts\tf.ps1 plan
pwsh pipeline\scripts\tf.ps1 apply
```
```bash
# Linux / macOS
pipeline/scripts/tf.sh init-local
pipeline/scripts/tf.sh plan
pipeline/scripts/tf.sh apply
```
`init-local` drops a git-ignored `backend_override.tf` (local backend) at the
root. Delete that file to return to remote state.

### Option B — against the SAME remote state as the pipeline

1. `cp pipeline/backend-config.local.tfbackend.example pipeline/backend-config.local.tfbackend`
   and fill in host / project id / username / personal access token (`api` scope).
2. Init + run:
   ```bash
   pipeline/scripts/tf.sh init-remote
   pipeline/scripts/tf.sh plan
   ```
   Use this for read/plan parity with CI. Prefer letting the pipeline perform
   `apply` so state changes stay auditable.

### Just validating (no backend, no creds)

```bash
pipeline/scripts/tf.sh fmt
pipeline/scripts/tf.sh validate
```

---

## Notes

- **`.terraform.lock.hcl` is committed** (run `terraform init` once locally and
  commit the result) so CI and local runs resolve identical provider versions.
- `prevent_destroy` is set on containers, networks and reverse zones, so the
  `destroy` action will fail by design — see the root README to intentionally
  remove a protected object.
- The image is pinned to the GitLab Terraform `stable` channel; pin to a
  specific tag if you need fully reproducible tooling versions.
