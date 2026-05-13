variable "name_prefix" {
  type        = string
  description = "Prefix applied to every resource name."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
}

variable "azs" {
  type        = list(string)
  description = "Availability zones to spread subnets across. List length determines the subnet count."
}

variable "eks_cluster_name" {
  type        = string
  description = "EKS cluster name used in subnet discovery tags."
}
