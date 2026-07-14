output "argocd_namespace" {
  value = module.cluster_bootstrap.argocd_namespace
}

output "observability_namespace" {
  value = module.cluster_bootstrap.observability_namespace
}

output "external_secrets_namespace" {
  value = module.cluster_bootstrap.external_secrets_namespace
}

output "app_namespace" {
  value = module.cluster_bootstrap.app_namespace
}

output "port_forward_hints" {
  value = module.cluster_bootstrap.port_forward_hints
}

output "next_steps" {
  description = "Commands to wire the GitOps loop after local cluster bootstrap."
  value       = <<-EOT
    Apply the local/demo ArgoCD apps from the repository root:

      kubectl apply -f infrastructure-cicd/argocd-apps/core-api-demo.yaml
      kubectl apply -f infrastructure-cicd/argocd-apps/observability.yaml

    Then watch sync:

      kubectl get applications -n ${module.cluster_bootstrap.argocd_namespace} -w
  EOT
}
