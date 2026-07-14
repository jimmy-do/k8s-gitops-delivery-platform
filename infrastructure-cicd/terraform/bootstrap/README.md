# Terraform Bootstrap

This root module is AWS-only and creates the S3 bucket plus DynamoDB table used
by the AWS Terraform environment for remote state and locking.

Local/demo mode does not use this module. It keeps local Terraform state because
kind, Docker Desktop Kubernetes, Colima, and KodeKloud clusters are temporary
targets and should not require AWS credentials.

Run this once from a trusted workstation with AWS admin credentials:

```bash
cd infrastructure-cicd/terraform/bootstrap
terraform init
terraform apply
```

Copy the `state_bucket` and `lock_table` outputs into
`infrastructure-cicd/terraform/envs/aws/backend.tf` if you change the defaults.
