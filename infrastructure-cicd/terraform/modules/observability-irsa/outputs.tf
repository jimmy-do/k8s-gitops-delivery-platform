output "external_secrets_role_arn" {
  description = "Consumed by observability/bootstrap/external-secrets/values.yaml SA annotation"
  value       = aws_iam_role.external_secrets.arn
}

output "slack_webhook_secret_arn" {
  value = aws_secretsmanager_secret.slack_webhook.arn
}

output "pagerduty_routing_key_secret_arn" {
  value = aws_secretsmanager_secret.pagerduty_routing_key.arn
}