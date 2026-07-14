# Kubernetes GitOps Delivery Platform

A production-style DevOps portfolio project that takes a small web service from container image to Kubernetes deployment, AWS infrastructure, GitOps delivery, and observability.

The goal of this project is not to show a toy Kubernetes manifest. It is to demonstrate the practical skills expected from a junior-to-mid DevOps or platform engineer: Docker, Helm, Argo CD, Terraform, AWS, CI/CD, Prometheus, Grafana, and incident-style troubleshooting.

## Deployment Modes

This repo supports two paths without mixing their credentials or blast radius.

**Local/demo mode** is for kind, Docker Desktop Kubernetes, Colima, KodeKloud, or any existing cluster with a working kubeconfig. It requires no AWS credentials. GitHub Actions validates the repo and can publish `ghcr.io/jimmy-do/core-api`; ArgoCD running inside the cluster pulls the `feature/local-gitops-mode` branch from this repo and syncs `container-platform/helm/core-api` with `values-local.yaml`.

**AWS mode** is the production-style path. Terraform creates AWS infrastructure and the protected `aws-apply.yml` workflow is manual-only through `workflow_dispatch`. AWS credentials, OIDC roles, remote state, ECR, EKS, and RDS are used only in this mode.

GitHub Actions intentionally does not deploy directly into KodeKloud or any temporary cluster. The delivery flow is:

```text
Developer pushes code
  -> GitHub Actions validates, lints, and builds
  -> GitHub Actions publishes an image to GHCR where appropriate
  -> ArgoCD running inside Kubernetes pulls from GitHub
  -> ArgoCD syncs the app into the cluster
```

## What This Demonstrates

This repository shows that I can:

- Package an application into a secure container image.
- Deploy it to Kubernetes with Helm using health probes, resource limits, security contexts, and NetworkPolicy.
- Use Argo CD so Git remains the source of truth for deployed state.
- Build AWS infrastructure with Terraform modules for VPC, ECR, EKS, RDS, IAM/OIDC, and remote state.
- Use GitHub Actions with AWS OIDC instead of long-lived cloud credentials.
- Expose application metrics and connect them to Prometheus, Grafana, and alerting rules.
- Debug real deployment issues across container registries, Kubernetes, Terraform, AWS, and observability tooling.

## Architecture

```mermaid
flowchart LR
  Dev["Developer"] --> GitHub["GitHub Repository"]
  GitHub --> Feature["feature/local-gitops-mode"]
  GitHub --> Main["main"]
  Feature --> Validate["validate.yml"]
  Main --> Validate
  Main --> Image["image.yml"]
  Image --> GHCR["GHCR image"]

  subgraph Local["Local / demo mode"]
    Kubeconfig["Existing cluster + kubeconfig"] --> LocalTF["Terraform envs/local"]
    LocalTF --> Argo["ArgoCD"]
    LocalTF --> Prom["Prometheus stack"]
    Feature --> Argo
    Argo --> LocalHelm["Helm chart + values-local.yaml"]
    LocalHelm --> LocalApp["core-api Pods"]
    GHCR --> LocalApp
  end

  subgraph AWS["AWS mode"]
    AWSApply["aws-apply.yml manual"] --> AWSTF["Terraform envs/aws"]
    AWSTF --> EKS["Amazon EKS"]
    AWSTF --> ECR["Amazon ECR"]
    AWSTF --> RDS["Amazon RDS PostgreSQL"]
    EKS --> AWSApp["core-api Pods"]
    ECR --> AWSApp
  end

  LocalApp --> Metrics["/metrics"]
  AWSApp --> Metrics
  Metrics --> Prom["Prometheus"]
  Prom --> Grafana["Grafana Dashboard"]
  Prom --> Alerts["PrometheusRule / Alertmanager"]
```

## Local Testing

The `feature/local-gitops-mode` branch is designed to test the complete GitOps loop against an existing Kubernetes cluster. Terraform installs the cluster services, then ArgoCD pulls desired state from GitHub and deploys `core-api`. No AWS credentials or AWS resources are used.

### Navigation Helper

The project-local `justfile` provides short, read-only commands for learning and checking the local/demo flow:

| Command | Purpose |
|---|---|
| `just flow` | Show the local GitOps path |
| `just terraform` | Inspect the local Terraform entrypoint, module call, and shared bootstrap ownership |
| `just argo` | Inspect the Argo CD Application handoff |
| `just helm-files` | Inspect local chart values and templates |
| `just helm-local` | Lint and render the chart with local values |
| `just cluster` | Inspect the current context, Argo CD, core-api, and optional monitoring resources |

Install `just` with `brew install just`. The dependency-free backend can also be run directly, for example `./scripts/dev-nav.sh flow`.

These commands do not apply Terraform, apply Kubernetes manifests, or deploy workloads. Git files describe desired state only; verify Terraform state, Argo CD sync state, and live Kubernetes state separately.

### Prerequisites

- Terraform `>= 1.6.0`
- `kubectl` configured for a reachable kind, Docker Desktop, Colima, KodeKloud, or other test cluster
- Git access to this repository
- Cluster egress to GitHub, GHCR, and the Argo CD and Prometheus Helm repositories

The local Terraform root installs ArgoCD and kube-prometheus-stack, so a local Helm CLI is optional unless you use the direct Helm fallback.

### 1. Select the Branch and Cluster

Run these commands from the repository root:

```bash
git switch feature/local-gitops-mode

kubectl config get-contexts
kubectl config current-context
kubectl cluster-info
```

Copy the local variables file and set `kube_context` to the exact context shown by `kubectl config current-context`:

```bash
cp infrastructure-cicd/terraform/envs/local/terraform.tfvars.example \
  infrastructure-cicd/terraform/envs/local/terraform.tfvars
```

Example:

```hcl
kube_context = "kind-portfolio"
```

Do not rely on the current context implicitly. The explicit value prevents Terraform from modifying the wrong cluster.

### 2. Bootstrap the Local Platform

Initialize, validate, plan, and apply the local Terraform root:

```bash
terraform -chdir=infrastructure-cicd/terraform/envs/local init
terraform -chdir=infrastructure-cicd/terraform/envs/local validate
terraform -chdir=infrastructure-cicd/terraform/envs/local plan -out=tfplan
terraform -chdir=infrastructure-cicd/terraform/envs/local apply tfplan
```

This creates the `argocd`, `monitoring`, and `core-api` namespaces and installs ArgoCD plus kube-prometheus-stack. External Secrets remains disabled by default in local mode.

Verify the platform services:

```bash
kubectl get pods -n argocd
kubectl get pods -n monitoring
```

### 3. Start the GitOps Reconciliation

Apply the ArgoCD Applications from the repository root:

```bash
kubectl apply -f infrastructure-cicd/argocd-apps/core-api-demo.yaml
kubectl apply -f infrastructure-cicd/argocd-apps/observability.yaml

kubectl get applications -n argocd
kubectl get applications -n argocd -w
```

`core-api-demo` tracks `feature/local-gitops-mode` and renders the Helm chart with `values.yaml` plus `values-local.yaml`. The observability configuration currently tracks `main`.

ArgoCD reads the remote GitHub branch, not the local working tree. Local edits must be committed and pushed before ArgoCD can reconcile them.

### 4. Verify the Application

Wait for the deployment and inspect the resulting resources:

```bash
kubectl -n core-api rollout status deployment/core-api --timeout=180s
kubectl -n core-api get pods,svc
kubectl -n argocd describe application core-api-demo
```

In a second terminal, forward the service:

```bash
kubectl -n core-api port-forward svc/core-api 18080:80
```

Test the application from the first terminal:

```bash
curl -fsS http://127.0.0.1:18080/
curl -fsS http://127.0.0.1:18080/health/live
curl -fsS http://127.0.0.1:18080/health/ready
curl -fsS http://127.0.0.1:18080/metrics
```

### 5. Test a GitOps Change

Change a local deployment value such as `replicaCount` in `container-platform/helm/core-api/values-local.yaml`, then push it to the tracked branch:

```bash
git add container-platform/helm/core-api/values-local.yaml
git commit -m "test local GitOps reconciliation"
git push origin feature/local-gitops-mode
```

ArgoCD polls Git automatically. To request an immediate refresh and watch reconciliation:

```bash
kubectl -n argocd annotate application core-api-demo \
  argocd.argoproj.io/refresh=hard --overwrite

kubectl -n argocd get application core-api-demo -w
kubectl -n core-api get pods -w
```

The feature branch runs `validate.yml`, but `image.yml` publishes automatically only from `main`. `values-local.yaml` therefore uses the existing `ghcr.io/jimmy-do/core-api:latest` image. To test application source changes from the feature branch, manually run `image.yml` for the branch and update `image.tag` to the generated SHA tag.

### 6. Open ArgoCD and Grafana

ArgoCD:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

Open `http://127.0.0.1:8080` and sign in as `admin`.

Grafana:

```bash
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```

Open `http://127.0.0.1:3000` and use the local credentials `admin` / `admin`.

### 7. Clean Up

Delete the ArgoCD Applications before destroying the Terraform-managed platform:

```bash
kubectl delete -f infrastructure-cicd/argocd-apps/observability.yaml
kubectl delete -f infrastructure-cicd/argocd-apps/core-api-demo.yaml

terraform -chdir=infrastructure-cicd/terraform/envs/local destroy
```

## Repository Layout

```text
container-platform/
  app/                    Flask service with health and metrics endpoints
  Dockerfile              Production-style container image
  helm/core-api/          Helm chart for Kubernetes deployment
  argocd/                 Argo CD application manifests

infrastructure-cicd/
  argocd-apps/            ArgoCD Applications for local/demo, AWS, observability
  github-actions/         CI/CD workflow documentation
  terraform/bootstrap/    S3 + DynamoDB remote state bootstrap
  terraform/envs/local/   kubeconfig-driven local/demo cluster bootstrap
  terraform/envs/aws/     protected AWS environment composition
  terraform/prod/         AWS production root module
  terraform/modules/      AWS platform, cluster bootstrap, VPC, EKS, ECR, RDS, IRSA

observability/
  external-secrets/       External Secrets Operator wrapper chart
  kube-prometheus-stack/  Prometheus, Alertmanager, and Grafana wrapper chart
  loki/                   Loki and Promtail wrapper charts
  core-api-observability/ ServiceMonitor, PrometheusRule, Grafana dashboard

docs/
  testing.md              What was validated and what was learned
  playground-runbook.md   Reproducible KodeKloud test sequence
```

## Platform Components

### Application Platform

The `core-api` service exposes:

- `GET /`
- `GET /health/live`
- `GET /health/ready`
- `GET /metrics`

The Helm chart includes:

- Deployment, Service, Ingress, ServiceAccount, HPA, and NetworkPolicy
- startup, liveness, and readiness probes
- CPU and memory requests/limits
- non-root container execution
- read-only root filesystem
- dropped Linux capabilities
- production override values for AWS/EKS-style deployment

### Infrastructure and CI/CD

Terraform manages:

- S3 and DynamoDB remote state backend
- VPC with public/private subnets across three AZs
- Internet Gateway, NAT Gateway, route tables, and subnet associations
- ECR repository and lifecycle policy
- EKS control plane and managed node group
- RDS PostgreSQL in private subnets
- IAM roles and policy attachments
- GitHub Actions OIDC provider and deploy role
- EKS access entry scoped to the application namespace

GitHub Actions is split by trust boundary:

- `validate.yml`: no AWS credentials; Terraform fmt/init/validate, Helm lint/template, ArgoCD YAML lint, Docker build.
- `image.yml`: no AWS credentials; builds and pushes `ghcr.io/jimmy-do/core-api` with `GITHUB_TOKEN`.
- `aws-apply.yml`: manual-only AWS Terraform path using OIDC and a protected GitHub environment.

Terraform is organized around environment intent:

- `terraform/bootstrap`: AWS-only S3/DynamoDB remote state bootstrap.
- `terraform/modules/aws-platform`: wraps the existing real VPC, EKS, ECR, RDS, IAM, and observability IRSA modules.
- `terraform/modules/cluster-bootstrap`: installs cluster foundation components into an existing Kubernetes cluster with Kubernetes/Helm providers.
- `terraform/envs/local`: kubeconfig-driven local/demo mode; no AWS provider or credentials.
- `terraform/envs/aws`: AWS mode; remote state, AWS provider, and optional second-phase cluster bootstrap using `data "aws_eks_cluster"` and `data "aws_eks_cluster_auth"`.

### Observability

The observability layer includes:

- Prometheus scraping through `ServiceMonitor`
- Grafana dashboard for core-api golden signals
- Prometheus alerts for error rate, pod restarts, and memory pressure
- External Secrets integration for Alertmanager webhook secrets
- Loki and Promtail wrappers for log collection

## Validation Status

This project has been tested in KodeKloud Kubernetes and AWS playground environments.

| Area | Validation | Result |
|---|---|---|
| Container image | Built, pushed to GHCR, pulled by Kubernetes | Passed |
| Multi-arch image | Rebuilt for amd64/arm64 compatibility | Passed |
| Helm deployment | Installed `core-api` with local playground overrides | Passed |
| App endpoints | `/`, `/health/live`, `/health/ready`, `/metrics` | Passed |
| Prometheus scrape | ServiceMonitor connected app metrics to Prometheus | Passed |
| Grafana | `core-api Golden Signals` dashboard imported and rendered | Passed |
| Terraform bootstrap | S3 backend bucket and DynamoDB lock table created | Passed |
| Terraform prod plan | Full AWS stack planned successfully | Passed |
| AWS apply | EKS and RDS created in KodeKloud after lab-specific overrides | Passed |

See [docs/testing.md](docs/testing.md) for the validation notes and [docs/playground-runbook.md](docs/playground-runbook.md) for the exact reproduction sequence.

## Key Troubleshooting Scenarios

Real issues found and resolved during testing:

- GHCR image pull failed with `401 Unauthorized` because the package was private.
- Kubernetes image pull failed because an Apple Silicon image did not match amd64 playground nodes.
- Prometheus returned no app metrics because ServiceMonitor labels did not match the live Service.
- Grafana dashboard ConfigMap targeted the wrong namespace for the playground install.
- Terraform `for_each` failed because RDS security group rules used apply-time values as keys.
- KodeKloud EKS required lab-approved IAM role names for `iam:PassRole`.
- RDS PostgreSQL `16.3` was unavailable in the playground region, requiring an available patch version.

These are the kinds of issues that happen in real platform work: auth, architecture, labels/selectors, state, IAM, cloud service constraints, and environment differences.

## Quick Start

Run Terraform formatting:

```bash
terraform -chdir=infrastructure-cicd/terraform fmt -check -recursive
```

Run Terraform validation for the prod root after backend initialization:

```bash
cd infrastructure-cicd/terraform/prod
terraform validate
```

For the complete `feature/local-gitops-mode` workflow, follow [Local Testing](#local-testing).

If you want to bypass ArgoCD and validate the application chart directly in a playground cluster:

```bash
helm upgrade --install core-api container-platform/helm/core-api \
  --namespace core-api \
  --create-namespace \
  --values container-platform/helm/core-api/values.yaml \
  --values container-platform/helm/core-api/values-local.yaml
```

Port-forward and test:

```bash
kubectl -n core-api port-forward svc/core-api 18080:80

curl http://127.0.0.1:18080/
curl http://127.0.0.1:18080/health/live
curl http://127.0.0.1:18080/health/ready
curl http://127.0.0.1:18080/metrics
```

## Troubleshooting

- Kubeconfig/context: set `kube_context` explicitly in `terraform/envs/local/terraform.tfvars`; do not rely on whatever context happens to be current.
- GHCR image pulls: public packages need no pull secret; private GHCR packages require a Kubernetes `docker-registry` secret with `read:packages`.
- ArgoCD sync: check `kubectl get applications -n argocd` and inspect the app in the ArgoCD UI.
- Missing namespaces: `cluster-bootstrap` creates `argocd`, `monitoring`, and `core-api`; ArgoCD Applications also use `CreateNamespace=true`.
- External Secrets local mode: disabled by default. Enable only after adding a fake or real `ClusterSecretStore`.
- AWS credentials: required only for `terraform/bootstrap`, `terraform/envs/aws`, and the manual `aws-apply.yml` workflow.

## Why This Project Matters

This project is intentionally scoped like work a DevOps engineer would do on a real team:

- create repeatable infrastructure
- ship application changes safely
- keep secrets out of Git
- make deployments observable
- document failure modes
- distinguish production design from playground constraints
