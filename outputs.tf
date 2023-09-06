output "web_acl_id" {
  value       = join("", aws_wafv2_web_acl.waf[*].arn)
  description = "WAF arn used with the cloudfront"
}

output "web_acl_arn" {
  value       = aws_wafv2_web_acl.waf.arn
  description = "Web ACL arn"
}

output "oracle_data_cloud_crawlers" {
  value       = local.oracle_data_cloud_crawlers
  description = "List of Oracle Data CLoud Crawlers whitelisted"
}
output "google_bots" {
  value = concat(
    [for ip in local.google_bots_ipv4 : ip if ip != null],
    [for ip in local.google_bots_ipv6 : ip if ip != null]
  )
  description = "List of Google bots whitelisted"
}
