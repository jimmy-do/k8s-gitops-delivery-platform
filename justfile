set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

# List the local/demo navigation commands.
default:
    @just --list

# Show the local GitOps path from desired state to live cluster inspection.
flow:
    @./scripts/dev-nav.sh flow

# Show local Terraform entrypoint files.
tf-entry:
    @./scripts/dev-nav.sh tf-entry

# Show the module call and source references in the local Terraform root.
tf-calls:
    @./scripts/dev-nav.sh tf-calls

# Show resources owned by the shared cluster bootstrap module.
tf-owns:
    @./scripts/dev-nav.sh tf-owns

# Run all local Terraform navigation checks.
terraform:
    @./scripts/dev-nav.sh terraform

# Show the local Argo CD Application manifests.
argo-files:
    @./scripts/dev-nav.sh argo-files

# Show Argo CD source and destination handoff fields.
argo-sources:
    @./scripts/dev-nav.sh argo-sources

# Run all Argo CD navigation checks.
argo:
    @./scripts/dev-nav.sh argo

# Show the local Helm chart values and templates.
helm-files:
    @./scripts/dev-nav.sh helm-files

# Lint the core-api chart with local/demo values.
helm-lint:
    @./scripts/dev-nav.sh helm-lint

# Render the core-api chart with local/demo values.
helm-render:
    @./scripts/dev-nav.sh helm-render

# Lint and render the local/demo Helm chart.
helm-local:
    @./scripts/dev-nav.sh helm-local

# Inspect the current Kubernetes context and local/demo workloads.
cluster:
    @./scripts/dev-nav.sh cluster
