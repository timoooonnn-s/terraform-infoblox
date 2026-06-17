###############################################################################
# Remote state backend: GitLab-managed Terraform HTTP state.
#
# Partial configuration on purpose -- no values are hard-coded here. They are
# supplied at `terraform init` time:
#   * In CI       -> automatically by the `gitlab-terraform` wrapper.
#   * By hand     -> via -backend-config (see pipeline/README.md ->
#                    "Running by hand against the same remote state").
#
# Purely local / offline experimentation:
#   Copy  pipeline/backend_override.tf.example  ->  ./backend_override.tf
#   (git-ignored). The override switches this to a local backend so you can
#   plan/apply without touching the shared remote state.
###############################################################################

terraform {
  backend "http" {}
}
