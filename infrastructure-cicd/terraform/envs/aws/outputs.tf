output "cluster_name" {
  value = module.aws_platform.cluster_name
}

output "cluster_endpoint" {
  value = module.aws_platform.cluster_endpoint
}

output "ecr_repository_url" {
  value       = module.aws_platform.ecr_repository_url
  description = "AWS/ECR image repository for protected AWS deployments."
}

output "rds_endpoint" {
  value = module.aws_platform.rds_endpoint
}

output "rds_master_password_secret_arn" {
  value = module.aws_platform.rds_master_password_secret_arn
}

output "github_actions_role_arn" {
  value       = module.aws_platform.github_actions_role_arn
  description = "OIDC role for AWS/ECR workflows if you choose to use the protected AWS image path."
}

output "external_secrets_role_arn" {
  value = module.aws_platform.external_secrets_role_arn
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.aws_platform.cluster_name}"
}

output "cluster_bootstrap_namespaces" {
  value = var.enable_cluster_bootstrap ? {
    argocd           = module.cluster_bootstrap[0].argocd_namespace
    observability    = module.cluster_bootstrap[0].observability_namespace
    external_secrets = module.cluster_bootstrap[0].external_secrets_namespace
    app              = module.cluster_bootstrap[0].app_namespace
  } : null
}
