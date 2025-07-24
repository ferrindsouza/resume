terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0.0"
    }
  }
  required_version = ">= 1.0"
}

# Default AWS Provider
provider "aws" {
  region = var.region
  profile = "Admin"
}

# ACM Provider for us-east-1 (required for CloudFront)
provider "aws" {
  alias  = "acm_provider"
  region = "us-east-1"
  profile = "Admin"
}
