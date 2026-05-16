output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_arn" {
  value = module.eks.cluster_arn
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "rds_endpoint" {
  value = var.rds_enabled ? module.rds[0].endpoint : null
}

output "rds_master_password_secret_arn" {
  value = var.rds_enabled ? module.rds[0].master_password_secret_arn : null
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "external_secrets_role_arn" {
  value = var.external_secrets_irsa_enabled ? module.observability_irsa[0].external_secrets_role_arn : null
}
