<#
.SYNOPSIS
  Local hand-run wrapper that mirrors the GitLab pipeline actions.

.DESCRIPTION
  Runs Terraform from the repository root regardless of where you invoke it.
  Credentials come from credentials.auto.tfvars (local) or TF_VAR_* env vars.

.EXAMPLE
  pwsh pipeline/scripts/tf.ps1 validate
  pwsh pipeline/scripts/tf.ps1 init-local      # local state, offline
  pwsh pipeline/scripts/tf.ps1 plan
  pwsh pipeline/scripts/tf.ps1 apply
#>
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("fmt", "validate", "init-local", "init-remote", "plan", "apply", "destroy")]
  [string]$Action
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $Root
try {
  switch ($Action) {
    "fmt"      { terraform fmt -check -recursive }
    "validate" { terraform init -backend=false; if ($?) { terraform validate } }
    "init-local" {
      Copy-Item "pipeline\backend_override.tf.example" "backend_override.tf" -Force
      terraform init
    }
    "init-remote" { terraform init -backend-config="pipeline\backend-config.local.tfbackend" }
    "plan"     { terraform plan }
    "apply"    { terraform apply }
    "destroy"  { terraform destroy }   # NOTE: blocked by prevent_destroy on managed objects
  }
}
finally { Pop-Location }
