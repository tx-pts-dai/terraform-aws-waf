terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.14"
    }
  }
}

data "aws_caller_identity" "current" {}
