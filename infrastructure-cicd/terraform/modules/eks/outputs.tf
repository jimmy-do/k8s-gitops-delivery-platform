output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_arn" {
  value       = aws_eks_cluster.this.arn
  description = "Referenced by the GitHub Actions IAM policy to scope eks:DescribeCluster."
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  value       = aws_eks_cluster.this.certificate_authority[0].data
  description = "Base64-encoded CA cert for kubectl/kubeconfig."
}

output "oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.cluster.arn
  description = "IRSA — service accounts trust this provider to assume IAM roles."
}

output "oidc_provider_url" {
  value = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "node_security_group_id" {
  value       = aws_security_group.node.id
  description = "RDS / other resources reference this to allow ingress from EKS nodes."
}

output "node_role_arn" {
  value = aws_iam_role.node.arn
}
