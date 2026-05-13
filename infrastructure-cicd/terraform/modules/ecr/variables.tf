variable "repository_name" {
  type        = string
  description = "ECR repository name. Becomes the path in the registry URL: <account>.dkr.ecr.<region>.amazonaws.com/<name>."
}

variable "scan_on_push" {
  type        = bool
  description = "Scan images for CVEs immediately on push."
  default     = true
}
