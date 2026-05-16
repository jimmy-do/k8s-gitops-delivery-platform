# Testing and Validation Notes

This document summarizes what was validated while building the Kubernetes GitOps Delivery Platform. It is written as an evidence trail: what was tested, what passed, what failed, and what was learned.

## Test Environments

| Environment | Purpose |
|---|---|
| Local development machine | Repository edits, Docker build workflow, Terraform formatting |
| KodeKloud Multi-node Kubernetes Playground | Kubernetes, Helm, app runtime, Prometheus, Grafana |
| KodeKloud Terraform + AWS Playground | Terraform bootstrap, AWS planning, real AWS resource creation |

## Phase 1: Container Platform

### Scope

Validated the application container and Kubernetes deployment path:

- Flask-based `core-api` service
- Docker image build and publish
- GHCR image pull from Kubernetes
- Helm deployment
- health probes
- Prometheus metrics endpoint

### Commands Used

```bash
helm upgrade --install core-api container-platform/helm/core-api \
  --namespace core-api \
  --create-namespace \
  --set image.repository=ghcr.io/jimmy-do/core-api \
  --set image.tag=latest \
  --set ingress.enabled=false \
  --set networkPolicy.enabled=false
```

```bash
kubectl -n core-api port-forward svc/core-api 18080:80

curl http://127.0.0.1:18080/
curl http://127.0.0.1:18080/health/live
curl http://127.0.0.1:18080/health/ready
curl http://127.0.0.1:18080/metrics
```

### Results

| Check | Result |
|---|---|
| Image pull from GHCR | Passed after package visibility was made public |
| Image architecture compatibility | Passed after publishing multi-arch image |
| Helm install | Passed with playground overrides |
| `/` endpoint | Passed |
| `/health/live` | Passed |
| `/health/ready` | Passed |
| `/metrics` | Passed |

### Issues Found

- GHCR package was private, causing `401 Unauthorized`.
- Initial image did not match the Kubernetes node architecture.
- NetworkPolicy and Ingress were disabled for the playground because the local environment did not need those production controls for endpoint validation.

## Phase 2: Infrastructure and CI/CD

### Scope

Validated Terraform structure and AWS provisioning behavior:

- remote state bootstrap
- prod root initialization
- Terraform formatting and validation
- full-stack plan
- partial apply behavior
- EKS and RDS creation after KodeKloud-specific overrides

### Non-Destructive Checks

```bash
terraform -chdir=infrastructure-cicd/terraform fmt -check -recursive
```

```bash
cd infrastructure-cicd/terraform/bootstrap
terraform init
terraform validate
terraform plan \
  -var='aws_region=us-east-1' \
  -var='environment=dev' \
  -var='project_name=k8s-gitops-delivery-platform-playground'
```

### Bootstrap Apply

Bootstrap created:

```text
S3 bucket:    k8s-gitops-delivery-platform-playground-tfstate-dev
Dynamo table: k8s-gitops-delivery-platform-playground-tflock-dev
```

Verification:

```bash
terraform output
aws s3 ls | grep k8s-gitops-delivery-platform-playground
```

### Prod Root Plan

The `prod` root was initialized against the playground backend:

```bash
terraform init -reconfigure \
  -backend-config="bucket=k8s-gitops-delivery-platform-playground-tfstate-dev" \
  -backend-config="key=infrastructure-cicd/prod/playground.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=k8s-gitops-delivery-platform-playground-tflock-dev" \
  -backend-config="encrypt=true"
```

The full stack produced:

```text
Plan: 45 to add, 0 to change, 0 to destroy.
```

### AWS Apply Notes

The AWS playground successfully created the core AWS resources after lab-specific adjustments:

- VPC
- subnets
- route tables
- Internet Gateway
- NAT Gateway
- Elastic IP
- ECR repository
- IAM roles and policy attachments
- GitHub Actions OIDC provider
- EKS cluster
- RDS PostgreSQL
- Secrets Manager resources

### Issues Found

- Playground Terraform CLI was `1.5.0`; the repo requires `>= 1.6.0`.
- `prod` backend configuration could not come from `playground.tfvars`; backend values had to be passed with `-backend-config`.
- RDS security group rule used unknown values as `for_each` keys.
- KodeKloud EKS required specific IAM role names for `iam:PassRole`.
- RDS PostgreSQL `16.3` was unavailable in `us-east-1`; `16.14` was available.
- A failed Terraform apply left partial state, which is expected Terraform behavior.

## Phase 3: Observability

### Scope

Validated application observability:

- kube-prometheus-stack installation
- Prometheus target discovery
- ServiceMonitor for `core-api`
- Grafana dashboard import
- PrometheusRule manifests
- Loki/Promtail wrapper chart structure
- External Secrets dependency model for Alertmanager webhooks

### Prometheus and Grafana Checks

Prometheus target/query checks:

```bash
curl -s 'http://127.0.0.1:9091/api/v1/targets' | grep core-api
curl -s 'http://127.0.0.1:9091/api/v1/query?query=http_requests_total'
```

Traffic generation:

```bash
for i in $(seq 1 100); do
  curl -s http://127.0.0.1:18080/ > /dev/null
done
```

Grafana access:

```bash
kubectl -n observability port-forward svc/prometheus-grafana 3000:80 --address 0.0.0.0
```

### Results

| Check | Result |
|---|---|
| Prometheus stack installed | Passed |
| Prometheus scraped `core-api` | Passed after Service label patch |
| `http_requests_total` query returned data | Passed |
| Grafana dashboard loaded | Passed |
| Dashboard showed golden signals | Passed |
| node-exporter | Known playground limitation |
| Alertmanager webhook delivery | Not fully tested; secret dependency documented |

### Issues Found

- node-exporter failed in KodeKloud due to likely host access restrictions.
- ServiceMonitor labels did not initially match the live Service labels.
- Grafana dashboard ConfigMap targeted `monitoring`, while the playground used `observability`.
- Prometheus metrics validation did not require External Secrets; only Alertmanager webhook delivery does.

## Overall Result

The project has now been validated across all three pillars:

```text
container-platform   -> application runtime and Kubernetes packaging
infrastructure-cicd  -> AWS infrastructure and Terraform workflow
observability        -> metrics, dashboarding, and alert rule structure
```

The strongest outcome is not just that the happy path worked. The project also produced real troubleshooting evidence across cloud IAM, Terraform state, Kubernetes selectors, container architecture, and observability integration.
