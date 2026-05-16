output "argocd_namespace" {
  value       = var.argocd_enabled ? kubernetes_namespace.argocd[0].metadata[0].name : null
  description = "Namespace where ArgoCD is installed, or null when disabled."
}

output "observability_namespace" {
  value       = var.observability_enabled ? kubernetes_namespace.monitoring[0].metadata[0].name : null
  description = "Namespace where kube-prometheus-stack is installed, or null when disabled."
}

output "external_secrets_namespace" {
  value       = var.external_secrets_enabled ? kubernetes_namespace.external_secrets[0].metadata[0].name : null
  description = "Namespace where External Secrets Operator is installed, or null when disabled."
}

output "app_namespace" {
  value       = kubernetes_namespace.app.metadata[0].name
  description = "Namespace where ArgoCD syncs app workloads."
}

output "port_forward_hints" {
  description = "Useful local port-forward commands for platform services."
  value = {
    argocd_ui    = var.argocd_enabled ? "kubectl port-forward -n ${var.argocd_namespace} svc/argocd-server 8080:443" : null
    argocd_pw    = var.argocd_enabled ? "kubectl get secret -n ${var.argocd_namespace} argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" : null
    grafana_ui   = var.observability_enabled ? "kubectl port-forward -n ${var.observability_namespace} svc/monitoring-grafana 3000:80" : null
    prometheus   = var.observability_enabled ? "kubectl port-forward -n ${var.observability_namespace} svc/monitoring-kube-prometheus-prometheus 9090:9090" : null
    alertmanager = var.observability_enabled ? "kubectl port-forward -n ${var.observability_namespace} svc/monitoring-kube-prometheus-alertmanager 9093:9093" : null
  }
}
