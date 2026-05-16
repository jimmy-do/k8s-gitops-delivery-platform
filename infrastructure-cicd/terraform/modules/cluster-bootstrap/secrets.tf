resource "helm_release" "external_secrets" {
  count = var.external_secrets_enabled ? 1 : 0

  name       = "external-secrets"
  namespace  = kubernetes_namespace.external_secrets[0].metadata[0].name
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.external_secrets_chart_version

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  values = [
    yamlencode({
      installCRDs = true
      serviceAccount = {
        annotations = var.external_secrets_service_account_annotations
      }
      resources = {
        requests = { cpu = "10m", memory = "32Mi" }
        limits   = { cpu = "100m", memory = "128Mi" }
      }
      webhook = {
        resources = {
          requests = { cpu = "10m", memory = "32Mi" }
          limits   = { cpu = "100m", memory = "64Mi" }
        }
      }
      certController = {
        resources = {
          requests = { cpu = "10m", memory = "32Mi" }
          limits   = { cpu = "100m", memory = "64Mi" }
        }
      }
    })
  ]
}
