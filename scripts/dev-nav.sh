#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

local_tf="infrastructure-cicd/terraform/envs/local"
bootstrap_module="infrastructure-cicd/terraform/modules/cluster-bootstrap"
argocd_apps="infrastructure-cicd/argocd-apps"
helm_chart="container-platform/helm/core-api"

header() {
  printf '\n=== %s ===\n' "$1"
}

show_file() {
  local file="$1"

  if command -v bat >/dev/null 2>&1; then
    bat --paging=never --style=header,numbers -- "$file"
  else
    printf '\n--- %s ---\n' "$file"
    sed -n '1,240p' "$file"
  fi
}

show_files() {
  local file
  for file in "$@"; do
    show_file "$file"
  done
}

show_flow() {
  header "Local GitOps flow"
  cat <<'EOF'
README.md
  -> infrastructure-cicd/terraform/envs/local
  -> infrastructure-cicd/terraform/modules/cluster-bootstrap
  -> infrastructure-cicd/argocd-apps/core-api-demo.yaml
  -> infrastructure-cicd/argocd-apps/observability.yaml
  -> container-platform/helm/core-api
  -> observability/core-api-observability
  -> kubectl / K9s live cluster verification

Git files describe desired state.
Terraform state records Terraform-managed infrastructure.
Argo CD reports reconciliation and sync state.
kubectl and K9s show the live Kubernetes state.
EOF
}

show_tf_entry() {
  header "Local Terraform entrypoint"
  show_files \
    "$local_tf/main.tf" \
    "$local_tf/providers.tf" \
    "$local_tf/variables.tf" \
    "$local_tf/terraform.tfvars.example"
}

show_tf_calls() {
  header "Local Terraform module calls"
  rg --heading --line-number --color=auto \
    --glob '*.tf' \
    'module "cluster_bootstrap"|source\s*=' \
    "$local_tf"
}

show_tf_owns() {
  header "Shared cluster bootstrap ownership"
  rg --heading --line-number --color=auto \
    --glob '*.tf' \
    'resource "|helm_release|kubernetes_namespace|kubernetes_manifest|kubectl_manifest' \
    "$bootstrap_module"
}

show_argo_files() {
  header "Argo CD handoff"
  show_files \
    "$argocd_apps/core-api-demo.yaml" \
    "$argocd_apps/observability.yaml"
}

show_argo_sources() {
  header "Argo CD source and destination fields"
  rg --heading --line-number --color=auto \
    'kind:\s*Application|repoURL:|targetRevision:|path:|valueFiles:|destination:' \
    "$argocd_apps"
}

show_helm_files() {
  header "Helm local chart"
  show_files \
    "$helm_chart/Chart.yaml" \
    "$helm_chart/values.yaml" \
    "$helm_chart/values-local.yaml"

  header "Helm templates"
  local templates=()
  while IFS= read -r file; do
    templates+=("$file")
  done < <(find "$helm_chart/templates" -maxdepth 1 -type f | sort)
  show_files "${templates[@]}"
}

helm_lint_local() {
  header "Helm local lint"
  helm lint "$helm_chart" \
    --values "$helm_chart/values.yaml" \
    --values "$helm_chart/values-local.yaml"
}

helm_render_local() {
  header "Helm local render"
  helm template core-api "$helm_chart" \
    --namespace core-api \
    --values "$helm_chart/values.yaml" \
    --values "$helm_chart/values-local.yaml"
}

optional_resource_check() {
  local resource="$1"
  local label="$2"

  if kubectl api-resources --api-group=monitoring.coreos.com -o name | rg -qx "$resource"; then
    kubectl get "$resource" -n core-api
  else
    printf '%s CRD is not installed; skipping.\n' "$label"
  fi
}

check_cluster() {
  header "Current Kubernetes context"
  kubectl config current-context

  header "Cluster nodes"
  kubectl get nodes

  header "Argo CD Applications"
  kubectl get applications -n argocd

  header "Argo CD pods"
  kubectl get pods -n argocd

  header "core-api workloads"
  kubectl get deploy,svc,pods -n core-api

  header "core-api observability resources"
  optional_resource_check "servicemonitors.monitoring.coreos.com" "ServiceMonitor"
  optional_resource_check "prometheusrules.monitoring.coreos.com" "PrometheusRule"
}

usage() {
  cat <<'EOF'
Usage: scripts/dev-nav.sh COMMAND

Commands:
  flow          Show the local GitOps flow map
  tf-entry      Show local Terraform entrypoint files
  tf-calls      Show what the local Terraform root calls
  tf-owns       Show resources owned by cluster-bootstrap
  terraform     Run tf-entry, tf-calls, and tf-owns
  argo-files    Show local Argo CD Application files
  argo-sources  Show Argo CD source and destination fields
  argo          Run argo-files and argo-sources
  helm-files    Show local Helm chart files and templates
  helm-lint     Lint the chart with local/demo values
  helm-render   Render the chart with local/demo values
  helm-local    Lint and render the local/demo chart
  cluster       Run read-only live cluster checks
EOF
}

case "${1:-}" in
  flow)
    show_flow
    ;;
  tf-entry)
    show_tf_entry
    ;;
  tf-calls)
    show_tf_calls
    ;;
  tf-owns)
    show_tf_owns
    ;;
  terraform)
    show_tf_entry
    show_tf_calls
    show_tf_owns
    ;;
  argo-files)
    show_argo_files
    ;;
  argo-sources)
    show_argo_sources
    ;;
  argo)
    show_argo_files
    show_argo_sources
    ;;
  helm-files)
    show_helm_files
    ;;
  helm-lint)
    helm_lint_local
    ;;
  helm-render)
    helm_render_local
    ;;
  helm-local)
    helm_lint_local
    helm_render_local
    ;;
  cluster)
    check_cluster
    ;;
  -h | --help | help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
