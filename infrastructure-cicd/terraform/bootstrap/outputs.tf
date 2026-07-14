output "state_bucket" {
  value       = aws_s3_bucket.tfstate.id
  description = "Use this in envs/aws/backend.tf as bucket = ..."
}

output "lock_table" {
  value       = aws_dynamodb_table.tflock.name
  description = "Use this in envs/aws/backend.tf as dynamodb_table = ..."
}
