#!/usr/bin/env bash
# Local hand-run wrapper that mirrors the GitLab pipeline actions.
# Runs Terraform from the repository root regardless of invocation directory.
# Credentials come from credentials.auto.tfvars (local) or TF_VAR_* env vars.
#
# Usage:
#   pipeline/scripts/tf.sh validate
#   pipeline/scripts/tf.sh init-local     # local state, offline
#   pipeline/scripts/tf.sh plan
#   pipeline/scripts/tf.sh apply
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

case "${1:-}" in
  fmt)         terraform fmt -check -recursive ;;
  validate)    terraform init -backend=false && terraform validate ;;
  init-local)  cp pipeline/backend_override.tf.example ./backend_override.tf && terraform init ;;
  init-remote) terraform init -backend-config=pipeline/backend-config.local.tfbackend ;;
  plan)        terraform plan ;;
  apply)       terraform apply ;;
  destroy)     terraform destroy ;;  # blocked by prevent_destroy on managed objects
  *)
    echo "Usage: $0 {fmt|validate|init-local|init-remote|plan|apply|destroy}" >&2
    exit 2
    ;;
esac
