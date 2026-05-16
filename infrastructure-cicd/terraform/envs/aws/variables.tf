variable "aws_region" {
  type        = string
  default     = "us-west-2"
  description = "AWS region for the production-style environment."
}

variable "project_name" {
  type        = string
  default     = "k8s-gitops-delivery-platform"
  description = "Project prefix for AWS resources."
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Environment name for tags and resource names."
}

variable "app_name" {
  type        = string
  default     = "core-api"
  description = "Application name."
}

variable "github_repository" {
  type        = string
  default     = "jimmy-do/k8s-gitops-delivery-platform"
  description = "GitHub owner/repo used for OIDC trust."
}

variable "availability_zones" {
  type        = list(string)
  default     = []
  description = "Optional explicit AZ list. Leave empty to use the first three available AZs."
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "eks_cluster_version" {
  type    = string
  default = "1.31"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_group_desired_size" {
  type    = number
  default = 2
}

variable "node_group_min_size" {
  type    = number
  default = 2
}

variable "node_group_max_size" {
  type    = number
  default = 4
}

variable "rds_enabled" {
  type    = bool
  default = true
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_engine_version" {
  type    = string
  default = "16.3"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "enable_cluster_bootstrap" {
  type        = bool
  default     = false
  description = "Set true after the EKS cluster exists to install ArgoCD, observability, and optional ESO into it."
}

variable "app_namespace" {
  type    = string
  default = "core-api"
}

variable "observability_enabled" {
  type    = bool
  default = true
}

variable "external_secrets_enabled" {
  type        = bool
  default     = true
  description = "Install External Secrets Operator in AWS mode and wire its service account to IRSA."
}

variable "external_secrets_namespace" {
  type    = string
  default = "external-secrets"
}
