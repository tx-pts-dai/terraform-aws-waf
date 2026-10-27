terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

locals {
  waf_name = "waf-logging-example"
  db_name  = replace(local.waf_name, "-", "_")
}

module "waf" {
  source = "../../"

  waf_name  = local.waf_name
  waf_scope = "CLOUDFRONT"
}

resource "aws_s3_bucket" "logs" {
  bucket        = "aws-waf-logs-${local.waf_name}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "waf-logs"
    status = "Enabled"

    expiration {
      days = 30
    }

    filter {}
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "waf" {
  resource_arn            = module.waf.web_acl_arn
  log_destination_configs = [aws_kinesis_firehose_delivery_stream.waf_logs.arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    query_string {}
  }

  logging_filter {
    default_behavior = "KEEP"

    filter {
      behavior    = "DROP"
      requirement = "MEETS_ALL"

      condition {
        action_condition {
          action = "ALLOW"
        }
      }

      condition {
        label_name_condition {
          label_name = "awswaf:managed:aws:amazon-ip-list:AWSManagedIPReputationList"
        }
      }
    }
  }
}
