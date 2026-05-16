module "aws_platform" {
  source = "../../modules/aws-platform"

  project_name       = var.project_name
  environment        = var.environment
  app_name           = var.app_name
  github_repository  = var.github_repository
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  eks_cluster_version     = var.eks_cluster_version
  node_instance_types     = var.node_instance_types
  node_group_desired_size = var.node_group_desired_size
  node_group_min_size     = var.node_group_min_size
  node_group_max_size     = var.node_group_max_size

  rds_enabled          = var.rds_enabled
  db_instance_class    = var.db_instance_class
  db_engine_version    = var.db_engine_version
  db_allocated_storage = var.db_allocated_storage

  external_secrets_irsa_enabled = var.external_secrets_enabled
  external_secrets_namespace    = var.external_secrets_namespace
}

module "cluster_bootstrap" {
  count = var.enable_cluster_bootstrap ? 1 : 0

  source = "../../modules/cluster-bootstrap"

  app_namespace              = var.app_namespace
  observability_enabled      = var.observability_enabled
  external_secrets_enabled   = var.external_secrets_enabled
  external_secrets_namespace = var.external_secrets_namespace

  external_secrets_service_account_annotations = var.external_secrets_enabled ? {
    "eks.amazonaws.com/role-arn" = module.aws_platform.external_secrets_role_arn
  } : {}

  argocd_values = {
    configs = {
      params = {
        "server.insecure" = false
      }
    }
  }

  kube_prometheus_stack_values = {
    prometheus = {
      prometheusSpec = {
        retention = "15d"
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = "gp3"
              accessModes      = ["ReadWriteOnce"]
              resources = {
                requests = {
                  storage = "50Gi"
                }
              }
            }
          }
        }
      }
    }
    grafana = {
      persistence = {
        enabled          = true
        storageClassName = "gp3"
        size             = "10Gi"
      }
    }
  }
}
