variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes minor version (e.g. \"1.30\")."
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Node group lives here exclusively."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Control plane ENIs placed here too for AZ redundancy."
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
  default = 6
}
