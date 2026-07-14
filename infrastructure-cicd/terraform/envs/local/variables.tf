variable "kubeconfig_path" {
  type        = string
  default     = "~/.kube/config"
  description = "Path to the kubeconfig used for local/demo cluster access."
}

variable "kube_context" {
  type        = string
  nullable    = false
  description = "Explicit kubectl context to target, for example kind-portfolio, docker-desktop, colima, or kubernetes-admin@kubernetes."
}

variable "app_namespace" {
  type        = string
  default     = "core-api"
  description = "Namespace where ArgoCD deploys core-api in local/demo mode."
}

variable "observability_enabled" {
  type        = bool
  default     = true
  description = "Install kube-prometheus-stack for local dashboards and ServiceMonitor CRDs."
}

variable "external_secrets_enabled" {
  type        = bool
  default     = false
  description = "Keep disabled in local/demo mode unless you also create a fake or real ClusterSecretStore."
}
