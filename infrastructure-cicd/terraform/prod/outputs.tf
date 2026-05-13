# =============================================================================
# outputs.tf — Surface values that CI and operators need.
#
# Each output is consumed by something concrete:
#   - github_actions_role_arn → CI workflow `role-to-assume`
#   - eks_cluster_name        → CI workflow + `aws eks update-kubeconfig`
#   - ecr_repository_url      → CI docker tag + values-prod.yaml image.repo
#   - rds_master_password_secret_arn → ESO config in-cluster
# =============================================================================

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnet_ids
  description = "Private subnets — EKS nodes and RDS live here."
}

output "ecr_repository_url" {
  value       = module.ecr.repository_url
  description = "Full ECR registry URL. CI pushes images here; values-prod.yaml references it."
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_oidc_provider_arn" {
  value       = module.eks.oidc_provider_arn
  description = "IRSA — service accounts in the cluster trust this provider to assume IAM roles."
}

output "rds_endpoint" {
  value       = module.rds.endpoint
  description = "RDS endpoint (host:port). Pulled into the cluster via External Secrets; never written to Git."
}

output "rds_master_password_secret_arn" {
  value       = module.rds.master_password_secret_arn
  description = "Secrets Manager ARN holding the RDS master password. ESO references this from the cluster."
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "IAM role ARN that GitHub Actions assumes via OIDC. Paste into the AWS_DEPLOY_ROLE_ARN GitHub secret."
}
