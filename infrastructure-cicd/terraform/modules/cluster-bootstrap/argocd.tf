resource "helm_release" "argocd" {
  count = var.argocd_enabled ? 1 : 0

  name       = "argocd"
  namespace  = kubernetes_namespace.argocd[0].metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  values = [
    yamlencode(merge(
      {
        configs = {
          params = {
            "server.insecure" = true
          }
        }
      },
      var.argocd_values
    ))
  ]
}
