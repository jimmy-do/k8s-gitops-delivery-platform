variable "argocd_enabled" {
  type        = bool
  default     = true
  description = "Install ArgoCD into the target cluster."
}

variable "argocd_namespace" {
  type        = string
  default     = "argocd"
  description = "Namespace where ArgoCD is installed."
}

variable "argocd_chart_version" {
  type        = string
  default     = "7.6.12"
  description = "Pinned argo-cd Helm chart version."
}

variable "argocd_values" {
  type        = any
  default     = {}
  description = "Additional ArgoCD Helm values merged onto module defaults."
}

variable "observability_enabled" {
  type        = bool
  default     = true
  description = "Install kube-prometheus-stack into the target cluster."
}

variable "observability_namespace" {
  type        = string
  default     = "monitoring"
  description = "Namespace where kube-prometheus-stack is installed."
}

variable "kube_prometheus_stack_version" {
  type        = string
  default     = "65.1.0"
  description = "Pinned kube-prometheus-stack Helm chart version."
}

variable "kube_prometheus_stack_values" {
  type        = any
  default     = {}
  description = "Additional kube-prometheus-stack Helm values merged onto module defaults."
}

variable "external_secrets_enabled" {
  type        = bool
  default     = false
  description = "Install External Secrets Operator. Local mode keeps this disabled unless a fake or real store is also wired."
}

variable "external_secrets_namespace" {
  type        = string
  default     = "external-secrets"
  description = "Namespace where External Secrets Operator is installed."
}

variable "external_secrets_chart_version" {
  type        = string
  default     = "0.10.4"
  description = "Pinned External Secrets Operator Helm chart version."
}

variable "external_secrets_service_account_annotations" {
  type        = map(string)
  default     = {}
  description = "Annotations for the External Secrets Operator service account, such as an AWS IRSA role."
}

variable "app_namespace" {
  type        = string
  default     = "demo"
  description = "Namespace where ArgoCD will sync application workloads."
}
