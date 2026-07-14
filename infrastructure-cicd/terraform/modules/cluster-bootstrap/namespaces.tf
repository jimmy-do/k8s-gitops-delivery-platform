resource "kubernetes_namespace" "argocd" {
  count = var.argocd_enabled ? 1 : 0

  metadata {
    name = var.argocd_namespace
    labels = {
      "pod-security.kubernetes.io/audit" = "restricted"
      "pod-security.kubernetes.io/warn"  = "restricted"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  count = var.observability_enabled ? 1 : 0

  metadata {
    name = var.observability_namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "baseline"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

resource "kubernetes_namespace" "external_secrets" {
  count = var.external_secrets_enabled ? 1 : 0

  metadata {
    name = var.external_secrets_namespace
    labels = {
      "pod-security.kubernetes.io/audit" = "restricted"
      "pod-security.kubernetes.io/warn"  = "restricted"
    }
  }
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}
