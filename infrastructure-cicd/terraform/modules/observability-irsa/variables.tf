variable "cluster_name" {
  type        = string
  description = "EKS cluster name used for IAM role and Secrets Manager resource names."
}

variable "eks_oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS OIDC provider used for IRSA trust."
}

variable "eks_oidc_provider_url" {
  type        = string
  description = "Issuer URL of the EKS OIDC provider."
}
