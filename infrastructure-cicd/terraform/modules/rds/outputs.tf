output "endpoint" {
  value       = aws_db_instance.this.endpoint
  description = "host:port — what an app uses to connect."
}

output "address" {
  value = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "master_password_secret_arn" {
  value       = aws_secretsmanager_secret.master_password.arn
  description = "ESO references this ARN to pull credentials into the cluster."
}
