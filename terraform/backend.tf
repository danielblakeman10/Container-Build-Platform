terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "danielblakeman-container-build-platform-tfstate"
    key          = "container-build-platform/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}