# GitHub Actions

The workflows are split so normal validation never needs cloud credentials.

## `validate.yml`

Runs on pull requests and pushes to long-lived development branches. It does not
use AWS secrets, kubeconfig, or cluster access.

Checks:

- `terraform fmt -check -recursive`
- `terraform init -backend=false`
- `terraform validate`
- `helm lint` and `helm template` for `container-platform/helm/core-api`
- ArgoCD app YAML linting
- Docker build with the repo's actual build context:

```yaml
context: container-platform
file: container-platform/Dockerfile
```

## `image.yml`

Builds and pushes the local/demo image to GHCR with `GITHUB_TOKEN`:

```text
ghcr.io/jimmy-do/core-api
```

This workflow has no AWS dependency. ArgoCD consumes the image through
`container-platform/helm/core-api/values-local.yaml`.

## `aws-apply.yml`

Manual-only AWS Terraform workflow. It is intentionally behind
`workflow_dispatch` and the `aws-prod` GitHub Environment so AWS infrastructure
cannot be changed by an ordinary push or pull request.

Set `AWS_DEPLOY_ROLE_ARN` as a GitHub Environment variable for `aws-prod`. The
role should be assumed through GitHub OIDC, not static access keys.

## Why CI Does Not Deploy To KodeKloud

KodeKloud and local clusters are temporary targets with kubeconfigs that should
not be copied into GitHub secrets. GitHub Actions validates, builds, and
publishes artifacts; ArgoCD running inside the cluster performs deployment by
pulling from GitHub.

That preserves the GitOps contract:

```text
Git is desired state.
ArgoCD reconciles cluster state.
CI proves and publishes artifacts.
```
