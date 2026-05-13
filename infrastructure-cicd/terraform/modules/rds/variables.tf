variable "identifier" {
  type        = string
  description = "RDS instance identifier. Used in resource names and the Secrets Manager path."
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnets for the DB subnet group. Multi-AZ failover requires 2+ AZs."
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "SGs allowed to talk to RDS on 5432. Typically the EKS node SG."
}

variable "db_name" {
  type    = string
  default = "coreapi"
}

variable "master_username" {
  type    = string
  default = "coreapi"
}
