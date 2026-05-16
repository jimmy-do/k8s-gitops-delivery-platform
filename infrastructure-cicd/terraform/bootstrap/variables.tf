variable "aws_region" {
  type        = string
  default     = "us-west-2"
  description = "AWS region for the remote-state bootstrap resources."
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Environment suffix for the state bucket and lock table."
}

variable "project_name" {
  type        = string
  default     = "k8s-gitops-delivery-platform"
  description = "Project prefix for the state bucket and lock table."
}
