terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  alias  = "us"
}

module "waf" {
  source = "../../"
  providers = {
    aws = aws.us
  }
  # Required variables: None

}
