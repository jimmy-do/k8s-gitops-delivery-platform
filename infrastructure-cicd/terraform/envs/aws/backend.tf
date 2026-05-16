terraform {
  backend "s3" {
    bucket         = "k8s-gitops-delivery-platform-tfstate-prod"
    key            = "infrastructure-cicd/envs/aws/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "k8s-gitops-delivery-platform-tflock-prod"
  }
}
