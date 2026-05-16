variable "project_name" {
  type        = string
  default     = "k8s-gitops-delivery-platform"
  description = "Project prefix for AWS resource names."
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Environment name used in AWS resource names and tags."
}

variable "app_name" {
  type        = string
  default     = "core-api"
  description = "Application name used for ECR, namespaces, and IAM scoping."
}

variable "github_repository" {
  type        = string
  default     = "jimmy-do/k8s-gitops-delivery-platform"
  description = "GitHub owner/repo allowed to assume the CI role."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for the AWS VPC."
}

variable "availability_zones" {
  type        = list(string)
  default     = []
  description = "Optional explicit AZ list. When empty, the first three available AZs in the provider region are used."
}

variable "eks_cluster_version" {
  type        = string
  default     = "1.31"
  description = "EKS Kubernetes version."
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "Managed node group instance types."
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
  type        = bool
  default     = true
  description = "Whether to create the RDS PostgreSQL instance."
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_engine_version" {
  type        = string
  default     = "16.3"
  description = "Pinned PostgreSQL engine version for RDS."
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "external_secrets_irsa_enabled" {
  type        = bool
  default     = true
  description = "Create an IRSA role and AWS secrets used by External Secrets Operator."
}

variable "external_secrets_namespace" {
  type        = string
  default     = "external-secrets"
  description = "Namespace of the External Secrets Operator service account."
}
