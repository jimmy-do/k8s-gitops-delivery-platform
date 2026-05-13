# =============================================================================
# modules/ecr — Container registry for the core-api image
# =============================================================================

resource "aws_ecr_repository" "this" {
  name = var.repository_name

  # Tag immutability: once a tag (like a git SHA) points at an image manifest,
  # it can never be overwritten. Prevents the "someone re-pushed prod and
  # rolled back what was running" class of incident.
  image_tag_mutability = "IMMUTABLE"

  # Scan every image immediately after push. Surfaces CVEs in the AWS console
  # and via EventBridge events. Complements Trivy in CI:
  #   - Trivy: blocks the push if CRITICAL/HIGH CVEs are found.
  #   - ECR scan: continuous re-scan as new CVEs are published — catches
  #     vulnerabilities that didn't exist on push day.
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  # Encrypt at rest with AWS-managed KMS. For stricter compliance, use a
  # customer-managed KMS key and grant the EKS node role kms:Decrypt on it.
  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Lifecycle policy — keep image storage bounded.
# Without this, every git push leaves a permanent image artifact and ECR
# storage costs grow forever.
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the last 30 tagged images."
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = 30
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after 7 days."
        # Untagged images are usually orphaned layers from failed pushes.
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      }
    ]
  })
}
