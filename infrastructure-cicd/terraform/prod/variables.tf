# =============================================================================
# variables.tf — Inputs to the prod root module
#
# Non-secret config only. Secrets (DB master password, app secrets) come
# from AWS Secrets Manager at runtime — never as Terraform variables, even
# via -var-file, because anything passed to terraform plan ends up in the
# state file in plaintext.
# =============================================================================

variable "aws_region" {
  type        = string
  description = "AWS region for all resources in this environment."
  default     = "us-west-2"
}

variable "environment" {
  type        = string
  description = "Environment name. Used in resource names and tags."
  default     = "prod"

  validation {
    # Enforced at plan time — catches typos like "prdo" before they create
    # resources with the wrong name.
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "environment must be one of: prod, staging, dev."
  }
}

variable "project_name" {
  type        = string
  description = "Project slug. Prefix for every resource name in this stack."
  default     = "k8s-gitops"
  # Kept short because AWS resource names have length limits (ALB names: 32,
  # security group names: 255, IAM role names: 64).
}

variable "app_name" {
  type        = string
  description = "Application name. Matches the Helm chart name from Phase 1."
  default     = "core-api"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC. /16 gives 65k addresses — plenty of room for future subnets without re-IPing."
  default     = "10.20.0.0/16"
  # 10.20.x.x chosen to NOT collide with the default Docker bridge
  # (172.17.0.0/16) or common corporate VPNs (10.0.0.0/16).
}

variable "eks_cluster_version" {
  type        = string
  description = "Kubernetes minor version for the EKS control plane."
  default     = "1.30"
  # EKS supports a rolling window of versions. Always lag the latest stable
  # by one minor — gives the ecosystem (CNIs, controllers) time to catch up.
}

variable "node_instance_types" {
  type        = list(string)
  description = "EC2 instance types for the EKS managed node group."
  default     = ["t3.medium"]
  # t3.medium = 2 vCPU, 4 GiB RAM — fits 4-6 portfolio-scale pods per node.
  # Real production picks based on workload profile and Spot availability.
}

variable "node_group_desired_size" {
  type        = number
  description = "Initial node count. HPA scales pods; Cluster Autoscaler / Karpenter scales nodes."
  default     = 2
}

variable "node_group_min_size" {
  type    = number
  default = 2
}

variable "node_group_max_size" {
  type        = number
  description = "Caps blast radius if a runaway HPA tries to add 100 nodes."
  default     = 6
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance class. db.t3.micro is portfolio-scale; real prod is db.r6g.large+."
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "github_org" {
  type        = string
  description = "GitHub organization or user name. Scopes the OIDC trust policy so only your repos can assume the deploy role."
  # CHANGE THIS in terraform.tfvars before applying.
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name. Used in the OIDC trust policy."
  default     = "k8s-gitops-delivery-platform"
}
