output "web_acl_id" {
  value       = join("", aws_wafv2_web_acl.waf[*].arn)
  description = "WAF arn used with the cloudfront"
}

output "web_acl_arn" {
  value       = aws_wafv2_web_acl.waf.arn
  description = "Web ACL arn"
}

output "ip_set_ids" {
  value = { for k, v in aws_wafv2_ip_set.whitelist : v.name => {
    id        = v.id
    arn       = v.arn
    addresses = v.addresses
    scope     = v.scope
  } }
  description = "Map of IP set name to ID created for the WAF"
}
