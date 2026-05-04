output "web_acl_id" {
  value       = join("", aws_wafv2_web_acl.waf[*].arn)
  description = "WAF arn used with the cloudfront"
}

output "web_acl_arn" {
  value       = aws_wafv2_web_acl.waf.arn
  description = "Web ACL arn"
}

output "logs_bucket_name" {
  value       = var.deploy_logs ? aws_s3_bucket.logs[0].id : null
  description = "Logs bucket name"
}

output "logs_bucket_arn" {
  value       = var.deploy_logs ? aws_s3_bucket.logs[0].arn : null
  description = "Logs bucket arn"
}

output "ip_set_ids" {
  value       = aws_wafv2_ip_set.whitelist[*].id
  description = "List of IP set IDs created for the WAF"
}
