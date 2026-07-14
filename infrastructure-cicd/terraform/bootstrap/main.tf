# =============================================================================
# bootstrap/main.tf — One-time setup of remote state infrastructure
#
# THE CHICKEN-AND-EGG PROBLEM
#   Terraform stores state in S3. To create the S3 bucket, Terraform needs
#   to run, which writes state. But there's no bucket yet to write to.
#
# THE SOLUTION
#   This config uses LOCAL state. Run it once per environment to create the
#   bucket + DynamoDB table. After that, every other root module uses S3
#   remote state, and this directory is rarely touched again.
#
# HOW TO RUN (only once, manually, by a human with admin creds):
#   $ cd infrastructure-cicd/terraform/bootstrap
#   $ terraform init        # local state, no backend block
#   $ terraform apply
#   $ git add terraform.tfstate terraform.tfstate.backup
#                           # commit bootstrap state
#                           # need it to manage the state bucket later.
# =============================================================================

terraform {
  required_version = ">= 1.6.0, < 2.0.0"
  # NO backend block — defaults to local terraform.tfstate.
}

# -----------------------------------------------------------------------------
# State bucket
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.project_name}-tfstate-${var.environment}"

  # Losing this bucket loses all Terraform state for the environment — and
  # with it, the ability to manage every resource Terraform created.
  # `terraform destroy` will fail until this lifecycle block is removed.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    # Every write to terraform.tfstate creates a new S3 version. If a corrupt
    # state is ever written, restore the previous version from the console.
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# Lock table
# -----------------------------------------------------------------------------

resource "aws_dynamodb_table" "tflock" {
  name = "${var.project_name}-tflock-${var.environment}"

  # On-demand pricing. This table sees ~10 writes/day; PAY_PER_REQUEST is
  # cheaper than the lowest provisioned tier and never throttles.
  billing_mode = "PAY_PER_REQUEST"

  # Terraform's S3 backend looks up a row by LockID = "<bucket>/<key>".
  hash_key = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}
