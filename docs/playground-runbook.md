# KodeKloud Playground Runbook

This runbook records the practical sequence used to test the project in KodeKloud playgrounds. It is intentionally separate from the production Terraform design because playgrounds have restrictions that real AWS accounts usually do not.

## Ground Rules

- Use playground-specific values such as `environment=dev`.
- Do not use production backend names in a temporary AWS account.
- Save plans with `-out` before applying.
- After a failed apply, inspect state before retrying.
- Treat KodeKloud-specific patches as lab overrides unless they are intentionally made configurable in the repo.

## Kubernetes Playground: core-api

Install the app with local overrides:

```bash
helm upgrade --install core-api container-platform/helm/core-api \
  --namespace core-api \
  --create-namespace \
  --set image.repository=ghcr.io/jimmy-do/core-api \
  --set image.tag=latest \
  --set ingress.enabled=false \
  --set networkPolicy.enabled=false
```

Check pods and service:

```bash
kubectl -n core-api get pods
kubectl -n core-api get svc
```

Port-forward:

```bash
kubectl -n core-api port-forward svc/core-api 18080:80 --address 0.0.0.0
```

Test endpoints:

```bash
curl http://127.0.0.1:18080/
curl http://127.0.0.1:18080/health/live
curl http://127.0.0.1:18080/health/ready
curl http://127.0.0.1:18080/metrics
```

## Kubernetes Playground: Observability

Install or verify the Prometheus/Grafana stack according to the chart wrapper values.

If the playground namespace is `observability`, apply the dashboard ConfigMap with a namespace rewrite:

```bash
sed 's/namespace: monitoring/namespace: observability/' \
  observability/core-api-observability/grafana-dashboard-configmap.yaml \
  | kubectl apply -f -
```

If Prometheus does not discover `core-api`, check labels:

```bash
kubectl -n core-api get svc core-api --show-labels
kubectl -n core-api get servicemonitor core-api --show-labels
```

Patch the Service label if needed:

```bash
kubectl -n core-api label svc core-api app.kubernetes.io/part-of=core-api --overwrite
```

Patch the ServiceMonitor release label if needed:

```bash
kubectl -n core-api label servicemonitor core-api release=prometheus --overwrite
```

Generate traffic:

```bash
for i in $(seq 1 100); do
  curl -s http://127.0.0.1:18080/ > /dev/null
done
```

Query Prometheus:

```bash
curl -s 'http://127.0.0.1:9091/api/v1/query?query=http_requests_total'
```

Open Grafana:

```bash
kubectl -n observability port-forward svc/prometheus-grafana 3000:80 --address 0.0.0.0
```

Expected dashboard:

```text
core-api Golden Signals
```

## AWS Playground: Terraform Version

Check Terraform version:

```bash
terraform version
```

If the playground has Terraform `1.5.0`, install a version that satisfies the repo constraint:

```bash
cd /tmp
curl -fsSLO https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
unzip -o terraform_1.6.6_linux_amd64.zip
install -m 0755 terraform /usr/local/bin/terraform
hash -r
terraform version
```

## AWS Playground: Bootstrap Backend

Format all Terraform:

```bash
cd ~/k8s-gitops-delivery-platform
terraform -chdir=infrastructure-cicd/terraform fmt -check -recursive
```

Plan bootstrap:

```bash
cd infrastructure-cicd/terraform/bootstrap

terraform init
terraform validate
terraform plan \
  -var='aws_region=us-east-1' \
  -var='environment=dev' \
  -var='project_name=k8s-gitops-delivery-platform-playground' \
  -out=tfplan
```

Apply bootstrap:

```bash
terraform apply "tfplan"
```

Verify outputs:

```bash
terraform output
aws s3 ls | grep k8s-gitops-delivery-platform-playground
```

Expected resources:

```text
k8s-gitops-delivery-platform-playground-tfstate-dev
k8s-gitops-delivery-platform-playground-tflock-dev
```

## AWS Playground: Prod Root Plan

Create playground variables:

```bash
cd ../prod

cat > playground.tfvars <<'EOF'
github_org = "jimmy-do"

aws_region   = "us-east-1"
environment  = "dev"
project_name = "k8s-gitops"

node_group_desired_size = 1
node_group_min_size     = 1
node_group_max_size     = 1

db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
EOF
```

Initialize with the playground backend:

```bash
terraform init -reconfigure \
  -backend-config="bucket=k8s-gitops-delivery-platform-playground-tfstate-dev" \
  -backend-config="key=infrastructure-cicd/prod/playground.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=k8s-gitops-delivery-platform-playground-tflock-dev" \
  -backend-config="encrypt=true"
```

Validate and plan:

```bash
terraform validate
terraform plan -var-file=playground.tfvars -out=tfplan
```

Expected successful plan shape:

```text
Plan: 45 to add, 0 to change, 0 to destroy.
```

## KodeKloud-Specific EKS Override

The KodeKloud AWS Playground allows EKS, but may restrict `iam:PassRole` to lab-approved role names.

If EKS fails with `iam:PassRole` for a custom role name, patch the playground clone only:

```bash
cd ~/k8s-gitops-delivery-platform

perl -0pi -e 's/name\s+= "\$\{var\.cluster_name\}-cluster-role"/name = "eksClusterRole"/' \
  infrastructure-cicd/terraform/modules/eks/main.tf

perl -0pi -e 's/name\s+= "\$\{var\.cluster_name\}-node-role"/name = "AmazonEKSNodeRole"/' \
  infrastructure-cicd/terraform/modules/eks/main.tf

terraform -chdir=infrastructure-cicd/terraform fmt -recursive
```

Do not apply an old saved plan after this edit. Create a new one:

```bash
cd infrastructure-cicd/terraform/prod
terraform plan -var-file=playground.tfvars -out=tfplan2
terraform apply "tfplan2"
```

## KodeKloud-Specific RDS Override

Check available PostgreSQL versions:

```bash
aws rds describe-db-engine-versions \
  --engine postgres \
  --query "DBEngineVersions[?starts_with(EngineVersion, '16.')].EngineVersion" \
  --output text
```

If `16.3` is unavailable and `16.14` is available, patch the playground clone only:

```bash
perl -0pi -e 's/engine_version = "16\.3"/engine_version = "16.14"/' \
  infrastructure-cicd/terraform/modules/rds/main.tf

terraform -chdir=infrastructure-cicd/terraform fmt -recursive
```

Create and apply a fresh plan:

```bash
cd infrastructure-cicd/terraform/prod
terraform plan -var-file=playground.tfvars -out=tfplan3
terraform apply "tfplan3"
```

## After a Failed Apply

Terraform apply is not an all-or-nothing transaction. Inspect state before retrying:

```bash
terraform state list
terraform output
```

Useful AWS checks:

```bash
aws eks list-clusters

aws ec2 describe-nat-gateways \
  --query 'NatGateways[].{Id:NatGatewayId,State:State}' \
  --output table

aws rds describe-db-instances \
  --query 'DBInstances[].DBInstanceIdentifier' \
  --output table
```

## Cleanup

In a disposable KodeKloud lab, resources are removed when the lab expires. For manual cleanup during the session:

```bash
cd infrastructure-cicd/terraform/prod
terraform destroy -var-file=playground.tfvars
```

Bootstrap resources include protective lifecycle settings, so they may require code changes before Terraform can destroy them. In the playground, it is usually acceptable to let the sandbox expire.

## What Counts as Success

Minimum successful validation:

```text
terraform fmt passes
bootstrap init/validate/plan passes
bootstrap apply creates S3/DynamoDB backend
prod init uses playground backend override
prod validate passes
prod plan succeeds
```

Full playground validation:

```text
EKS creates successfully
RDS creates successfully
Terraform state reflects the created stack
AWS console shows expected resources
```
