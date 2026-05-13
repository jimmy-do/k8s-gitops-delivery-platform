# =============================================================================
# main.tf — Root module wiring for the prod environment
#
# Composes the four child modules and creates the GitHub Actions OIDC role.
# Reading top-to-bottom is the dependency order:
#   providers → data → networking → registry → cluster → database → CI auth
# =============================================================================

# -----------------------------------------------------------------------------
# Provider
# -----------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  # Default tags applied to every taggable resource. Critical for:
  #   - Cost allocation (which team burned that $4000 NAT egress bill?)
  #   - Ownership during incidents (who do I page about this orphan?)
  #   - Cleanup (terraform-managed=true makes ad-hoc resources easy to spot)
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Application = var.app_name
      ManagedBy   = "terraform"
      Repo        = "${var.github_org}/${var.github_repo}"
    }
  }
}

# -----------------------------------------------------------------------------
# Data sources — read-only lookups
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  # state = available filters out AZs that are technically in the region but
  # not currently accepting new resources (rare, but it happens during AZ
  # capacity events).
  state = "available"
}

# -----------------------------------------------------------------------------
# Locals — derived values used in multiple places
# -----------------------------------------------------------------------------

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Take the first 3 AZs from the region. us-west-2 has 4 AZs; we only need 3
  # for HA and limiting to 3 keeps NAT + subnet costs predictable.
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

# -----------------------------------------------------------------------------
# Networking — VPC, subnets, NAT, route tables
# -----------------------------------------------------------------------------

module "vpc" {
  source = "../modules/vpc"

  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  azs         = local.azs

  # EKS needs subnets tagged so it can discover them for LoadBalancer Service
  # and Ingress provisioning. The module reads this name and stamps the right
  # tags on each subnet (kubernetes.io/cluster/<name>, role/elb, role/internal-elb).
  eks_cluster_name = "${local.name_prefix}-eks"
}

# -----------------------------------------------------------------------------
# Container registry — ECR repo for the core-api image
# -----------------------------------------------------------------------------

module "ecr" {
  source = "../modules/ecr"

  repository_name = var.app_name

  # Scan-on-push catches CVEs before any pod ever pulls the image.
  # Complements Trivy in CI (defense in depth: different DB, different timing).
  scan_on_push = true
}

# -----------------------------------------------------------------------------
# EKS — control plane, node group, IRSA OIDC provider
# -----------------------------------------------------------------------------

module "eks" {
  source = "../modules/eks"

  cluster_name    = "${local.name_prefix}-eks"
  cluster_version = var.eks_cluster_version
  vpc_id          = module.vpc.vpc_id

  # Node group lives in PRIVATE subnets (no public IPs on workers).
  # The control plane endpoint is reachable from the public internet by
  # default — for stricter security, set endpoint_public_access = false and
  # access via VPN / bastion / Session Manager.
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  node_instance_types     = var.node_instance_types
  node_group_desired_size = var.node_group_desired_size
  node_group_min_size     = var.node_group_min_size
  node_group_max_size     = var.node_group_max_size
}

# -----------------------------------------------------------------------------
# RDS — managed PostgreSQL for the core-api
# -----------------------------------------------------------------------------

module "rds" {
  source = "../modules/rds"

  identifier         = "${local.name_prefix}-${var.app_name}"
  instance_class     = var.db_instance_class
  allocated_storage  = var.db_allocated_storage
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # The EKS node security group is allowed to talk to RDS on 5432.
  # Pod-to-RDS access is then further restricted by Kubernetes NetworkPolicy
  # (the core-api chart's networkpolicy.yaml from Phase 1).
  allowed_security_group_ids = [module.eks.node_security_group_id]
}

# =============================================================================
# GitHub Actions OIDC — short-lived AWS creds for CI, no long-lived keys
#
# How OIDC works:
#   1. GitHub Actions presents an OIDC token signed by
#      token.actions.githubusercontent.com.
#   2. AWS verifies the signature against the OIDC provider created below.
#   3. The token's `sub` claim (repo + branch + workflow) must match the
#      trust policy's StringLike condition.
#   4. AWS returns short-lived (1 hour) STS credentials.
#
# Compared to long-lived IAM access keys stored in GitHub Secrets:
#   - Nothing to rotate or leak.
#   - The trust policy locks creds to a specific repo + branch — even a
#     leaked workflow file from another repo can't assume this role.
# =============================================================================

# Look up GitHub's TLS cert thumbprint at apply time. The aws_iam_openid_connect_provider
# resource still requires this field even though AWS now ignores it for the
# github.com provider (since 2023). Passing the actual thumbprint is defensive
# in case AWS reverts behavior.
data "tls_certificate" "github_oidc" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_oidc.certificates[0].sha1_fingerprint]
}

# Trust policy: only this repo's workflows running on main can assume this role.
# The StringLike condition with `:ref:refs/heads/main` prevents:
#   - Workflows from forks or other repos
#   - Pull-request workflows (which use :pull_request: in the sub claim)
#   - Workflows running on non-main branches in this repo
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      # Scope: only main branch, only this repo.
      # For PR builds, also add `repo:org/repo:pull_request`.
      values = ["repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${local.name_prefix}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}

# Least-privilege CI permissions: push to one ECR repo + describe one EKS
# cluster. Nothing else.
#
# Notably absent: any RDS, S3 (other than the state bucket via a separate
# state role), Secrets Manager write. CI doesn't deploy infra — Terraform does.
data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid = "ECRAuth"
    # GetAuthorizationToken can't be scoped to a specific repo — it's
    # account-level by design.
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ECRPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages",
    ]
    resources = [module.ecr.repository_arn]
  }

  statement {
    sid       = "EKSDescribe"
    actions   = ["eks:DescribeCluster"]
    resources = [module.eks.cluster_arn]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "ecr-push-and-eks-describe"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}

# -----------------------------------------------------------------------------
# EKS Access Entry — bind the CI role to a Kubernetes RBAC scope.
#
# Without this, the CI role has eks:DescribeCluster (it can read the API
# endpoint) but no Kubernetes-level permissions, so kubectl commands fail
# with "User cannot list resource ...".
#
# Scoped to the core-api namespace only with the AWS-managed EKSEditPolicy
# (lets CI run rollout undo as a deploy-safety backstop). The PRIMARY rollback
# mechanism is git revert → ArgoCD re-sync; this kubectl path is for the
# narrow case where you need to bypass ArgoCD during an incident.
# -----------------------------------------------------------------------------

resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [var.app_name]
  }
}
