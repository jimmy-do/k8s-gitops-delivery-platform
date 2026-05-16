# IRSA role for the ESO controller. Trust policy is locked to ONE specific ServiceAccount in
# ONE specific namespace — no other workload in the cluster can assume this role even if it
# steals the OIDC provider trust.
locals {
  oidc_provider_hostpath = replace(var.eks_oidc_provider_url, "https://", "")
}

data "aws_iam_policy_document" "eso_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.eks_oidc_provider_arn] # from module.eks outputs
    }

    # Pinning to a specific SA in a specific namespace — defense-in-depth that makes IRSA worth
    # using over node IAM role. Same pattern Phase 2 used for github_actions role.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_hostpath}:sub"
      values   = ["system:serviceaccount:${var.external_secrets_namespace}:${var.external_secrets_service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.cluster_name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.eso_trust.json

  tags = { Component = "observability", Purpose = "ESO controller IRSA" }
}

# Secrets Manager: created EMPTY by Terraform. Webhook values filled in out-of-band by an
# operator via the AWS console. ignore_changes on secret_string prevents `terraform apply` from
# wiping the value on every run — exactly the same pattern as the RDS password secret from Phase 2.
resource "aws_secretsmanager_secret" "slack_webhook" {
  name        = "/${var.cluster_name}/alertmanager/slack-webhook"
  description = "Slack webhook URL for Alertmanager severity:warning routing"

  lifecycle { prevent_destroy = true }
}

resource "aws_secretsmanager_secret_version" "slack_webhook_placeholder" {
  secret_id     = aws_secretsmanager_secret.slack_webhook.id
  secret_string = "PLACEHOLDER_REPLACE_VIA_CONSOLE"

  lifecycle { ignore_changes = [secret_string] }
}

resource "aws_secretsmanager_secret" "pagerduty_routing_key" {
  name        = "/${var.cluster_name}/alertmanager/pagerduty-routing-key"
  description = "PagerDuty routing key for Alertmanager severity:critical routing"

  lifecycle { prevent_destroy = true }
}

resource "aws_secretsmanager_secret_version" "pd_routing_key_placeholder" {
  secret_id     = aws_secretsmanager_secret.pagerduty_routing_key.id
  secret_string = "PLACEHOLDER_REPLACE_VIA_CONSOLE"

  lifecycle { ignore_changes = [secret_string] }
}

# Least-privilege permissions: read-only on the two specific webhook secret ARNs.
# NOT secretsmanager:* and NOT resources = ["*"]. Interview-defensible answer when asked
# "what stops ESO from reading the RDS password?" → "the IAM policy doesn't allow that ARN."
data "aws_iam_policy_document" "eso_read_webhooks" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      aws_secretsmanager_secret.slack_webhook.arn,
      aws_secretsmanager_secret.pagerduty_routing_key.arn,
    ]
  }
}

resource "aws_iam_role_policy" "eso_read_webhooks" {
  name   = "read-webhook-secrets"
  role   = aws_iam_role.external_secrets.id
  policy = data.aws_iam_policy_document.eso_read_webhooks.json
}
