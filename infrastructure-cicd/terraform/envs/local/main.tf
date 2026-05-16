module "cluster_bootstrap" {
  source = "../../modules/cluster-bootstrap"

  app_namespace            = var.app_namespace
  observability_enabled    = var.observability_enabled
  external_secrets_enabled = var.external_secrets_enabled

  external_secrets_service_account_annotations = {}
}
