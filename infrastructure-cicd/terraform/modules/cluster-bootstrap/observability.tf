resource "helm_release" "kube_prometheus_stack" {
  count = var.observability_enabled ? 1 : 0

  name       = "monitoring"
  namespace  = kubernetes_namespace.monitoring[0].metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_version

  wait          = true
  wait_for_jobs = true
  timeout       = 900

  values = [
    yamlencode(merge(
      {
        prometheus = {
          prometheusSpec = {
            resources = {
              requests = { cpu = "100m", memory = "256Mi" }
              limits   = { cpu = "500m", memory = "1Gi" }
            }
            retention = "6h"
          }
        }
        grafana = {
          adminPassword = "admin"
          resources = {
            requests = { cpu = "50m", memory = "128Mi" }
            limits   = { cpu = "200m", memory = "256Mi" }
          }
          persistence = { enabled = false }
        }
        alertmanager = {
          alertmanagerSpec = {
            resources = {
              requests = { cpu = "25m", memory = "64Mi" }
              limits   = { cpu = "100m", memory = "128Mi" }
            }
          }
        }
      },
      var.kube_prometheus_stack_values
    ))
  ]
}
