# =============================================================================
# backend.tf — Terraform remote state for the prod environment
#
# WHY remote state (S3) vs a local terraform.tfstate file:
#   - Local state is a single point of failure: lose the laptop, lose infra.
#   - Local state can't be shared across a team or a CI runner.
#   - S3 gives versioning (recover from corruption) and encryption at rest.
#
# WHY DynamoDB for locking:
#   - Two engineers (or two CI runs) hitting `terraform apply` at the same
#     time would race to write state.tfstate — guaranteed corruption.
#   - DynamoDB writes a row keyed on the state-file path while an apply is
#     in flight. The second apply sees the lock and fails fast with
#     "Error acquiring the state lock" — by design.
#
# WHY directory-per-environment instead of `terraform workspace`:
#   - Workspaces share ONE backend config, which makes it easy to apply
#     to prod by mistake when you meant staging.
#   - This layout (terraform/prod/, terraform/staging/) gives each env its
#     own state bucket. Prod IAM creds are required even to READ prod state.
#   - This is the consensus production pattern at Bay Area startups.
#
# IMPORTANT: values in the `backend` block MUST be literal strings.
#   Terraform parses the backend block before variables are resolved, so
#   var.aws_region or ${var.environment} silently fail here. To swap per
#   environment, use `terraform init -backend-config=prod.backend.hcl`.
# =============================================================================

terraform {
  backend "s3" {
    # These values are environment-specific. Each environment (prod, staging,
    # dev) has its own backend.tf with its own bucket name. Separate buckets
    # mean prod state is in a separate blast radius from dev.
    bucket = "k8s-gitops-delivery-platform-tfstate-prod"

    # Path within the bucket. Mirrors the repo structure — each root module
    # gets its own key. If observability/ becomes Terraform-managed later,
    # its state goes at observability/prod/terraform.tfstate.
    key = "infrastructure-cicd/prod/terraform.tfstate"

    region = "us-west-2"

    # SSE-S3 encryption at rest. For stricter compliance (customer-managed
    # KMS key, audit logging on key use), specify `kms_key_id`.
    encrypt = true

    # DynamoDB table with partition key `LockID` (String).
    # Schema is documented in bootstrap/main.tf.
    dynamodb_table = "k8s-gitops-delivery-platform-tflock-prod"
  }
}
