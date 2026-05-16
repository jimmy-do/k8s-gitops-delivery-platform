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

variable "external_secrets_namespace" {
  type        = string
  default     = "external-secrets"
  description = "Namespace containing the External Secrets Operator service account."
}

variable "external_secrets_service_account_name" {
  type        = string
  default     = "external-secrets"
  description = "External Secrets Operator service account name."
}
