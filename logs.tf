
resource "aws_athena_workgroup" "waf" {
  name          = "waf-logs-${var.waf_name}"
  force_destroy = true
  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.logs.bucket}/query-results/"
    }
  }
}

resource "aws_athena_database" "waf" {
  name          = "waf_logs_${replace(var.waf_name, "-", "_")}"
  force_destroy = true
  bucket        = aws_s3_bucket.logs.bucket
  comment       = "database for WAF logs"
}

resource "aws_athena_named_query" "waf_logs_table" {
  count     = var.deploy_athena_queries ? 1 : 0
  name      = "partition-projection-table-creation-${var.waf_name}"
  workgroup = aws_athena_workgroup.waf.id
  database  = aws_athena_database.waf.name
  query = templatefile("${path.module}/athena_queries/waf_logs_table.sql.tftpl",
    {
      bucket_name  = aws_s3_bucket.logs.id
      account_id   = data.aws_caller_identity.current.account_id
      waf_scope    = lower(var.waf_scope)
      web_acl_name = var.waf_name
    }
  )
}

resource "aws_athena_named_query" "requests_per_client_ip" {
  count     = var.deploy_athena_queries ? 1 : 0
  name      = "requests-per-client-ip-per-5min-${var.waf_name}"
  workgroup = aws_athena_workgroup.waf.id
  database  = aws_athena_database.waf.name
  query     = file("${path.module}/athena_queries/client_ip_per_5min.sql")
}

resource "aws_athena_named_query" "count_group_by" {
  count     = var.deploy_athena_queries ? 1 : 0
  name      = "count-requests-grouped-by-ip-tenant-endpoint-${var.waf_name}"
  workgroup = aws_athena_workgroup.waf.id
  database  = aws_athena_database.waf.name
  query     = file("${path.module}/athena_queries/count_requests_grouped_by_ip_tenant_endpoint.sql")
}

resource "aws_athena_named_query" "blocked_requests" {
  count     = var.deploy_athena_queries ? 1 : 0
  name      = "requests-blocked-${var.waf_name}"
  workgroup = aws_athena_workgroup.waf.id
  database  = aws_athena_database.waf.name
  query     = file("${path.module}/athena_queries/blocked_requests.sql")
}

resource "aws_athena_named_query" "per_ip_blocked_requests" {
  count     = var.deploy_athena_queries ? 1 : 0
  name      = "requests-blocked-per-client-ip-${var.waf_name}"
  workgroup = aws_athena_workgroup.waf.id
  database  = aws_athena_database.waf.name
  query     = file("${path.module}/athena_queries/per_ip_blocked_requests.sql")
}

resource "aws_athena_named_query" "first_logs_query" {
  count     = var.deploy_athena_queries ? 1 : 0
  name      = "first-ten-results-${var.waf_name}"
  workgroup = aws_athena_workgroup.waf.id
  database  = aws_athena_database.waf.name
  query     = "SELECT * FROM waf_logs limit 10;"
}

resource "aws_s3_bucket" "logs" {
  bucket        = coalesce(var.logs_bucket_name_override, "aws-waf-logs-${var.waf_name}-${data.aws_caller_identity.current.account_id}")
  force_destroy = true
}

# See issue <https://github.com/hashicorp/terraform-provider-aws/issues/28353>
resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logs" {
  bucket = aws_s3_bucket.logs.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.logs]
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.bucket
  rule {
    id = "waf-logs"
    expiration {
      days = var.waf_logs_retention
    }
    status = "Enabled"
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "logs" {
  count                   = var.enable_logging ? 1 : 0
  log_destination_configs = [aws_s3_bucket.logs.arn]
  resource_arn            = aws_wafv2_web_acl.waf.arn
}
