# =============================================================================
# versions.tf — Terraform CLI + provider version constraints for prod root.
#
# Kept separate from backend.tf for readability. Either file would work, but
# convention at scale is: backend.tf = where state lives, versions.tf = what
# versions are allowed.
#
# Why pin versions:
#   - A newer Terraform CLI can rewrite state in a format older versions
#     can't read. Pinning prevents accidental upgrades from breaking CI or
#     the rest of the team.
#   - Major provider versions can include breaking schema changes
#     (resource renames, attribute removals). ~> 5.0 means "any 5.x".
#   - The .terraform.lock.hcl file (committed to Git) pins the EXACT
#     resolved provider version across every team member and CI runner.
# =============================================================================

terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # tls used by main.tf to fetch the GitHub OIDC cert thumbprint.
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    # random used inside the RDS module for the master password.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
