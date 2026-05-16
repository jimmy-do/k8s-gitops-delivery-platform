data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  azs         = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source = "../vpc"

  name_prefix      = local.name_prefix
  vpc_cidr         = var.vpc_cidr
  azs              = local.azs
  eks_cluster_name = "${local.name_prefix}-eks"
}
