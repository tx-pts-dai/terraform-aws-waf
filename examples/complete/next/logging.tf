data "aws_caller_identity" "current" {
  provider = aws.us
}

resource "aws_s3_bucket" "waf_logs" {
  provider      = aws.us
  bucket        = "aws-waf-logs-waf-module-regression-example-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "waf_logs" {
  provider = aws.us
  bucket   = aws_s3_bucket.waf_logs.id

  rule {
    id     = "waf-logs"
    status = "Enabled"

    expiration {
      days = 7
    }

    filter {}
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "waf" {
  provider                = aws.us
  resource_arn            = module.waf.web_acl_arn
  log_destination_configs = [aws_s3_bucket.waf_logs.arn]
}

resource "aws_wafv2_web_acl_logging_configuration" "waf_parallel" {
  provider                = aws.us
  resource_arn            = module.waf_parallel.web_acl_arn
  log_destination_configs = [aws_s3_bucket.waf_logs.arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ANY"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }

      condition {
        action_condition {
          action = "CAPTCHA"
        }
      }
    }
  }
}
