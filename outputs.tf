output "web_acl_id" {
  value       = join("", aws_wafv2_web_acl.waf[*].arn)
  description = "WAF arn used with the cloudfront"
}

output "web_acl_arn" {
  value       = aws_wafv2_web_acl.waf.arn
  description = "Web ACL arn"
}

output "google_bots" {
  value = concat(
    [for ip in local.google_bots_ipv4 : ip if ip != null],
    [for ip in local.google_bots_ipv6 : ip if ip != null]
  )
  description = "List of Google bots whitelisted"
}


output "logs_bucket_name" {
  value       = var.deploy_logs ? aws_s3_bucket.logs[0].id : null
  description = "Logs bucket name"
}

output "logs_bucket_arn" {
  value       = var.deploy_logs ? aws_s3_bucket.logs[0].arn : null
  description = "Logs bucket arn"
}

# output "new_required_variable" {
#   value       = var.new_required_variable
#   description = "breaking change variable"
# }
