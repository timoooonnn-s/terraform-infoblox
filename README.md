# Infoblox NIOS — Terraform Network Provisioning

Terraform code for creating Infoblox NIOS network **containers**, child **networks**
(explicit or next-available), and **reverse DNS zones** from a single map/object
variable structure, using the official `infobloxopen/infoblox` provider (≤ 2.12.0).

---

## File structure

```
infoblox-tf/
├── main.tf                          # Provider config + module call
├── variables.tf                     # Root variables (connection, views, EA map, data)
├── outputs.tf                       # Root outputs
├── versions.tf                      # Terraform & provider version constraints
├── backend.tf                       # Remote state (GitLab HTTP) — partial config
├── terraform.tfvars                 # Operational config (example, non-secret)
├── credentials.auto.tfvars.example  # Credential template -> copy to .auto.tfvars
├── .gitlab-ci.yml                   # Thin stub -> includes pipeline/gitlab-ci.yml
├── .gitignore
├── pipeline/                        # Self-contained CI + hand-run tooling
│   ├── gitlab-ci.yml                # validate -> plan -> apply (manual)
│   ├── scripts/{tf.ps1,tf.sh}       # local wrappers mirroring the pipeline
│   ├── backend_override.tf.example  # -> ./backend_override.tf for local state
│   ├── backend-config.local.tfbackend.example
│   └── README.md                    # pipeline + hand-run docs
└── modules/
    └── network/
        ├── main.tf                  # Containers, networks, reverse zones + EA logic
        ├── variables.tf            # Typed contract + validation
        ├── outputs.tf
        └── versions.tf
```

---

## Prerequisites (both local and pipeline)

| Requirement | Detail |
|-------------|--------|
| **Terraform ≥ 1.3** | Required for `optional()` object attributes. Check with `terraform version`. |
| **Network access to the Grid** | Whatever runs `plan`/`apply` (your laptop or the CI runner) must reach the NIOS Grid Manager over HTTPS (port 443 by default). |
| **A NIOS WAPI account** | Username/password with permission to create networks, containers and DNS zones. |
| **EA definitions in the Grid** | Any advanced attribute you use (VLAN, VRF, Location, …) must already exist as an Extensible Attribute definition in NIOS. See [Extensible Attributes](#extensible-attributes-the-advanced-attributes). |

The two usage modes share the same code and the same `terraform.tfvars`. The
**only** difference is *where state lives* and *where credentials come from*:

| | Credentials | State |
|--|-------------|-------|
| **Local** | `credentials.auto.tfvars` (a local, git-ignored file) | local file, or the shared remote |
| **Pipeline** | GitLab CI/CD variables (`TF_VAR_*`) | GitLab-managed remote state |

You never edit committed files to switch between them.

---

## A. Running locally with Terraform — step by step

### Step 1 — Install Terraform

Install Terraform ≥ 1.3 (https://developer.hashicorp.com/terraform/install) and
confirm:

```powershell
terraform version
```

### Step 2 — Get the code

Clone the repo (or copy this folder) and open a shell **in the project root**
(the folder containing `main.tf`).

### Step 3 — Enter your credentials

Copy the template to the real, git-ignored credentials file and fill it in:

```powershell
# Windows / PowerShell
Copy-Item credentials.auto.tfvars.example credentials.auto.tfvars
```
```bash
# Linux / macOS
cp credentials.auto.tfvars.example credentials.auto.tfvars
```

Then edit `credentials.auto.tfvars`:

```hcl
infoblox_username = "your-wapi-user"
infoblox_password = "your-wapi-password"
```

> `credentials.auto.tfvars` is in `.gitignore` and must **never** be committed.
> Terraform loads any `*.auto.tfvars` file automatically.

### Step 4 — Set your operational config

Edit `terraform.tfvars` (this one **is** committed — it holds no secrets):

- `infoblox_host` — your Grid Manager hostname/IP
- `infoblox_port`, `infoblox_sslmode`, `infoblox_wapi_version` — usually leave as-is
- `network_view`, `dns_view`, `default_ns_group`
- `ea_keys` — **only** uncomment/override if your Grid's EA names differ from the defaults
- `network_containers` — your containers and networks (see [Variable structure](#variable-structure))

### Step 5 — Choose how state is stored

The committed `backend.tf` points at the **remote** (GitLab) backend, so a bare
`terraform init` will prompt you for backend settings. For local work pick one
of these — the helper scripts do it for you and only touch **git-ignored**
files, so nothing committed changes.

**Option A — offline, local state (recommended for first run / testing)**

State is kept in a local `terraform.tfstate` file. Independent from the
pipeline's state.

```powershell
# Windows / PowerShell
pwsh pipeline\scripts\tf.ps1 init-local
```
```bash
# Linux / macOS
pipeline/scripts/tf.sh init-local
```

<details><summary>What that does (manual equivalent)</summary>

```bash
cp pipeline/backend_override.tf.example ./backend_override.tf   # git-ignored
terraform init
```
The override file swaps the remote backend for a local one. Delete
`backend_override.tf` to go back to remote state.
</details>

**Option B — the same remote state as the pipeline**

Use this when you want your local runs to see exactly what CI manages.

1. Copy and fill the backend config (git-ignored):
   ```bash
   cp pipeline/backend-config.local.tfbackend.example pipeline/backend-config.local.tfbackend
   ```
   Set `<GITLAB_HOST>`, `<PROJECT_ID>`, `<USERNAME>`, and a personal access
   token (`api` scope) for `<TOKEN>`.
2. Initialise against it:
   ```powershell
   pwsh pipeline\scripts\tf.ps1 init-remote
   ```

### Step 6 — Validate, plan, apply

```powershell
# Windows / PowerShell
pwsh pipeline\scripts\tf.ps1 validate   # fmt check + terraform validate (no Grid needed)
pwsh pipeline\scripts\tf.ps1 plan       # shows what will change (talks to the Grid)
pwsh pipeline\scripts\tf.ps1 apply      # creates/updates objects after you confirm
```
```bash
# Linux / macOS
pipeline/scripts/tf.sh validate
pipeline/scripts/tf.sh plan
pipeline/scripts/tf.sh apply
```

<details><summary>Raw Terraform equivalents (after Step 5 init)</summary>

```bash
terraform fmt -check -recursive
terraform validate
terraform plan
terraform apply        # type "yes" to confirm
```
</details>

### Step 7 — Read the results

```bash
terraform output            # all outputs
terraform output networks   # just the created networks (id + resolved CIDR)
```

### Step 8 — Make a change later

Edit `terraform.tfvars` → `plan` → `apply`. Add a new container or network by
adding a key to the map; Terraform creates only the new objects.

### Step 9 — Removing objects (important)

`prevent_destroy` is enabled, so `terraform destroy` and any plan that would
**delete** a container/network/zone will fail on purpose. To intentionally
remove one, see [Safety: prevent_destroy](#safety-prevent_destroy).

---

## B. Running in a GitLab pipeline — step by step

All pipeline logic lives in [`pipeline/`](pipeline/README.md); the root
`.gitlab-ci.yml` is a one-line stub that includes it. You configure things **in
the GitLab UI**, not in the code.

### Step 1 — Push the repository to GitLab

Create a GitLab project and push this repo to it. GitLab auto-detects the root
`.gitlab-ci.yml`.

> Optional: instead of the stub, go to **Settings → CI/CD → General pipelines →
> CI/CD configuration file** and set it to `pipeline/gitlab-ci.yml`, then delete
> the root `.gitlab-ci.yml`.

### Step 2 — Commit the provider lock file

So CI and everyone else resolve identical provider versions, generate and
commit the lock file once:

```bash
terraform init        # creates .terraform.lock.hcl
git add .terraform.lock.hcl
git commit -m "Add provider lock file"
git push
```
(`.terraform.lock.hcl` is intentionally **not** git-ignored.)

### Step 3 — Add the credential variables in GitLab

Go to **Settings → CI/CD → Variables → Add variable** and create:

| Key | Value | Type | Flags |
|-----|-------|------|-------|
| `TF_VAR_infoblox_username` | your WAPI username | Variable | ✅ Masked, ✅ Protected |
| `TF_VAR_infoblox_password` | your WAPI password | Variable | ✅ Masked, ✅ Protected |
| `TF_VAR_infoblox_host` | Grid Manager host *(optional — overrides `terraform.tfvars`)* | Variable | ✅ Protected |

Terraform reads `TF_VAR_*` automatically, so **no credentials file is used in
CI**. "Protected" limits them to protected branches (e.g. `main`); keep your
default branch protected.

### Step 4 — Make sure a runner can reach the Grid

The `plan` and `apply` jobs call the NIOS WAPI. Confirm under **Settings →
CI/CD → Runners** that an available runner exists **and that it has network
access to `infoblox_host`**. If the Grid is on a private network, use a
self-hosted runner there. (`validate`/`fmt` need neither the runner-to-Grid path
nor credentials.)

### Step 5 — Open a merge request

Create a branch, edit `terraform.tfvars`, and open a merge request. The pipeline
runs automatically:

1. **`validate`** — `terraform fmt -check` + `terraform validate`.
2. **`plan`** — runs `terraform plan`, uploads the plan as an artifact, and
   shows a **Terraform report in the MR widget** so reviewers see exactly what
   will change.

Review the plan in the MR before merging.

### Step 6 — Merge and apply

1. Merge the MR into the default branch. The pipeline runs `validate` + `plan`
   again on the default branch.
2. The **`apply`** job is **manual**: open **Build → Pipelines**, find the
   pipeline for your merge commit, and click ▶ on the `apply` job.
3. `apply` consumes the **exact plan** produced in the same pipeline (so what
   you reviewed is what's applied) and writes to the GitLab-managed remote
   state. A `resource_group` ensures two applies never run at once.

### Step 7 — Confirming results

Open the `apply` job log to see the created/updated objects, or run
`terraform output` locally using **Option B** state from
[Section A, Step 5](#step-5--choose-how-state-is-stored).

### Recap: the everyday pipeline workflow

```
branch → edit terraform.tfvars → push → open MR
      → review the plan in the MR widget → merge
      → click ▶ "apply" on the default-branch pipeline
```

For the full pipeline reference (variables, per-environment state, image
pinning) see **[pipeline/README.md](pipeline/README.md)**.

---

## Variable structure

```hcl
network_containers = {
  corp = {                          # logical name (also the resource key)
    cidr     = "10.0.0.0/16"        # REQUIRED for a container
    comment  = "Corporate container"
    vrf      = "CORP"               # optional EA (see EA mapping)
    location = "HQ"

    networks = {
      users = {
        cidr                = "10.0.1.0/24"   # explicit  -- OR --
        # prefix_len        = 24              # next-available from the container
        gateway             = "10.0.1.1"
        reserve_ip          = 0
        vlan_id             = 100
        create_reverse_zone = true
      }
      guest = {
        prefix_len          = 24              # auto-allocated /24
        vlan_id             = 300
        create_reverse_zone = true
      }
    }
  }
}
```

Each network must set **exactly one** of `cidr` or `prefix_len` (validated).

---

## Mandatory vs optional

### Mandatory
| Field | Where | Notes |
|-------|-------|-------|
| `infoblox_host` / `username` / `password` | tfvars | connection |
| container `cidr` | each container | explicit CIDR |
| network `cidr` **or** `prefix_len` | each network | exactly one |

### Optional enhancements
| Field | Applies to | Default |
|-------|-----------|---------|
| `comment` | container, network | logical name |
| `gateway` | network | provider default (first usable IP) |
| `reserve_ip` | network | `0` |
| `create_reverse_zone` | network | `false` |
| `reverse_zone_view`, `reverse_zone_ns_group` | network | global defaults |
| EA attributes (below) | container, network | unset |
| `extra_ext_attrs` | container, network | `{}` |

---

## Extensible Attributes (the "advanced" attributes)

`VLAN ID, I-SID, VRF, Location, NetType, Discovery, Zone Group, Subzone Group,
XMC End System Group` are **not native arguments** in the Terraform provider.
They are written as **NIOS Extensible Attributes** via `ext_attrs`.

- The EA **definitions must already exist** in your Grid (this provider cannot
  create EA definitions).
- The keys used are controlled by `ea_keys` and **must match your Grid's EA
  definition names exactly**, or apply fails. Override in `terraform.tfvars`:

  ```hcl
  ea_keys = {
    vlan_id              = "VLAN"
    isid                 = "I-SID"
    vrf                  = "VRF"
    location             = "Location"
    nettype              = "NetType"
    discovery            = "Discovery"
    zone_group           = "Zone Group"
    subzone_group        = "Subzone Group"
    xmc_end_system_group = "XMC End System Group"
  }
  ```

- Need an EA not in the list? Use the free-form `extra_ext_attrs = { "My EA" = "value" }`.

---

## Validation built in

- **VLAN ID** must be 1–4094 (containers and networks).
- **I-SID** must be 0–16777215 (24-bit).
- Each network sets **exactly one** of `cidr` / `prefix_len`.
- **Duplicate CIDR detection** across containers and explicitly-defined networks.

---

## Safety: `prevent_destroy`

`lifecycle { prevent_destroy = true }` is set on **containers, networks, and
reverse zones**. `terraform destroy` (or any plan that would delete one of
these) will **fail by design**.

To intentionally remove a protected object you must edit the module
(`modules/network/main.tf`) and remove/relax the relevant `prevent_destroy`
block, then apply. `prevent_destroy` is a compile-time literal in Terraform and
cannot be toggled by a variable.

---

## Provider limitations & workarounds

1. **DHCP member assignment is not supported.** The provider's
   `infoblox_ipv4_network` resource has no `members` argument, so DHCP-serving
   Grid members cannot be assigned through Terraform. This was intentionally
   **omitted** from the design. Options if you need it later:
   - Record the intended member name in `extra_ext_attrs` (documentation only —
     **not** functional).
   - Manage member assignment directly in NIOS.
   - Drive the WAPI via the `Mastercard/restapi` provider or a wrapper script
     (out of scope for this native module).

2. **Native attributes are EA-only.** VLAN/I-SID/VRF/Location/NetType/Discovery/
   Zone Group/Subzone Group/XMC End System Group are stored as EAs, not native
   NIOS fields, because the provider exposes no native arguments for them.

3. **Overlap detection is partial.** Pure HCL cannot test subnet *containment*
   or arbitrary *overlap* (there is no CIDR-contains function). The module
   detects **duplicate CIDRs** statically; true overlap / out-of-container
   placement is caught **server-side by NIOS** at apply time.

4. **`ext_attrs` drift.** If the Grid auto-adds EAs (e.g. cloud/IPAM defaults),
   `terraform plan` may show ext_attrs differences. If this is noisy in your
   environment, add a targeted `lifecycle { ignore_changes = [ext_attrs] }`
   (note: this disables drift detection for all EAs on that resource).

5. **Reverse zones for next-available networks** resolve their `fqdn` from the
   allocated CIDR at **apply** time (the plan shows it as known-after-apply).

---

## Outputs

| Output | Description |
|--------|-------------|
| `network_containers` | `{ key => { id, cidr } }` |
| `networks` | `{ container/network => { id, cidr } }` (resolved CIDRs) |
| `reverse_zones` | `{ container/network => { id, fqdn } }` |
