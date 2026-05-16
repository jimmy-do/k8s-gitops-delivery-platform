module "rds" {
  count = var.rds_enabled ? 1 : 0

  source = "../rds"

  identifier         = "${local.name_prefix}-${var.app_name}"
  instance_class     = var.db_instance_class
  engine_version     = var.db_engine_version
  allocated_storage  = var.db_allocated_storage
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  allowed_security_group_ids = [module.eks.node_security_group_id]
}
