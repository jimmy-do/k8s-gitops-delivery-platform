terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Application = var.app_name
      ManagedBy   = "terraform"
      Repo        = var.github_repository
    }
  }
}

data "aws_eks_cluster" "this" {
  count = var.enable_cluster_bootstrap ? 1 : 0
  name  = module.aws_platform.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  count = var.enable_cluster_bootstrap ? 1 : 0
  name  = module.aws_platform.cluster_name
}

provider "kubernetes" {
  host                   = var.enable_cluster_bootstrap ? data.aws_eks_cluster.this[0].endpoint : "https://127.0.0.1"
  cluster_ca_certificate = var.enable_cluster_bootstrap ? base64decode(data.aws_eks_cluster.this[0].certificate_authority[0].data) : null
  token                  = var.enable_cluster_bootstrap ? data.aws_eks_cluster_auth.this[0].token : null
  insecure               = var.enable_cluster_bootstrap ? false : true
}

provider "helm" {
  kubernetes {
    host                   = var.enable_cluster_bootstrap ? data.aws_eks_cluster.this[0].endpoint : "https://127.0.0.1"
    cluster_ca_certificate = var.enable_cluster_bootstrap ? base64decode(data.aws_eks_cluster.this[0].certificate_authority[0].data) : null
    token                  = var.enable_cluster_bootstrap ? data.aws_eks_cluster_auth.this[0].token : null
    insecure               = var.enable_cluster_bootstrap ? false : true
  }
}
