# Waf Module

This module provides WAF resources to attach to cloudfront distribution or load balancer

## Core concepts

This module create the AWS WAF Web ACLs and AWS WAF IP sets necessary to protect a Cloudfront or LB.

It's designed to propose the following rules:

- Allow all requests comming from own AWS account (IP list)
- Allow all requests comming from list of IPv4 (IP list)
- Allow all requests comming from list of IPv6 (IP list)
- Allow all requests comming from partner (detect "host" header)
- (optionally) allow requests from Oracle Data Cloud Crawler
- (optionally) allow requests from Google bots
- AWS managed rules
- AWS managed count rules
- Limit requests starting with "/search"
- (optionally) limit requests based on uri path
- Block some articles for some coutries
- Limit requests per countries
- Limit not in limited countries (everybody_else)
- Count Swiss requests

## Waf logging

The module will also deploy several `AWS Athena` resources by default. These includes:

* an `Athena workgroup`
* an `Athena database`
* several `Athena queries`
* and an S3 bucket where waf logs will be saved if activated.

To activare waf logs set the `var.enable_logging` to `true` (`false` by default).

### Query WAF logs
In order to be able to query WAF logs saved on the S3 Bucket, we need to use the AWS Athena service:

* Once Logs have been activated we need to connect to Athena service via AWS console.
* Select the correct workgroup
* Here among the list of "Saved queries", you can find a query named "partition-projection-table-creation"
* If a table with the same name already exists, please delete it
* Set the query parameters as described in the query comments and run it
* Now a partition table is available and queries can be executed against the WAF logs stored on S3

Note: whenever WAF attachment changes, the partition projection table has to be deleted and recreated by updating the correct S3 bucket path. The table is created thorugh the query partition-projection-table-creation

## How do you use this module?

Create the following new module block with the desired parameters (in `waf.tf`?)

INFO: for cloudfront the aws provider should be in us-west-1 region.

```HCL
module "waf" {
  providers = {
    aws = aws.us
  }

  self_ips                = module.cf_extractor.public_ips # ie. NAT gateways
  allowed_ips             = var.waf_allowed_ips
  allowed_ips_v6          = var.waf_allowed_ips_v6
  country_rates           = var.waf_country_rates
  block_articles          = var.waf_block_articles
  aws_managed_count_rules = var.waf_aws_managed_rules
  allowed_partners        = var.waf_allowed_partners
  everybody_else_limit    = var.waf_everybody_else_limit
  search_limitation       = var.waf_search_limitation
}
```

For a list of all variables please refer to: [terraform-dock](terraform-docs.md)

### Waf scope: CLOUDFRONT or REGIONAL

By setting the variable `waf_scope` to `REGIONAL` (default is `CLOUDFRONT`) this module will create the described web ACL rules regionally, and it will be possible to attach such rules to an ALB or an API Gateway using the `aws_wafv2_web_acl_association`.

```hcl
resource "aws_wafv2_web_acl_association" "example" {
  resource_arn = aws_api_gateway_stage.example.arn
  # (Required) The Amazon Resource Name (ARN) of the resource to associate with the web ACL. This must be an ARN of an
  # Application Load Balancer or an Amazon API Gateway stage.
  web_acl_arn  = aws_wafv2_web_acl.waf.arn
}
```

### REGIONAL waf notes:

General considerations for using forwarded IP addresses

Before you use a forwarded IP address, note the following general caveats:

A header can be modified by proxies along the way, and the proxies might handle the header in different ways.
Attackers might alter the contents of the header in an attempt to bypass AWS WAF inspections.
The IP address inside the header can be malformed or invalid.
The header that you specify might not be present at all in a request.
Considerations for using forwarded IP addresses with AWS WAF

The following list describes requirements and caveats for using forwarded IP addresses in AWS WAF:

For any single rule, you can specify one header for the forwarded IP address. The header specification is case insensitive.
For rate-based rule statements, any nested scoping statements do not inherit the forwarded IP configuration. Specify the configuration for each statement that uses a forwarded IP address.
For geo match and rate-based rules, AWS WAF uses the first address in the header. For example, if a header contains “10.1.1.1, 127.0.0.0, 10.10.10.10”, AWS WAF uses “10.1.1.1”.
For IP set match, you indicate whether to match against the first, last, or any address in the header. If you specify any, AWS WAF inspects all addresses in the header for a match, up to 10 addresses. If the header contains more than 10 addresses, AWS WAF inspects the last 10.
Headers that contain multiple addresses must use a comma separator between the addresses. If a request uses a separator other than a comma, AWS WAF considers the IP addresses in the header malformed.
If the IP addresses inside the header are malformed or invalid, AWS WAF designates the web request as matching the rule or not matching, according to the fallback behavior that you specify in the forwarded IP configuration.
If the header that you specify isn’t present in a request, AWS WAF doesn’t apply the rule to the request at all. This means that AWS WAF doesn't apply the rule action and doesn't apply the fallback behavior.
A rule statement that uses a forwarded IP header for the IP address won’t use the IP address that’s reported by the web request origin. ([source](https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-forwarded-ip-address.html))

## Problems with the Oracle Data Cloud Crawler or Google bots ?

If the oracle data cloud regex throws errors the automatic parsing can be disabled by:
* setting `enable_oracle_crawler_whitelist = false`

If the `data.http.oracle` structure throws errors the url can be overriden by:
* setting the variable `oracle_data_cloud_crawlers_url` to a valid URL

If the google bot jsonecode throws errors it can be disabled by:
* setting `enable_google_bots_whitelist = false`

If the `data.http.googlebot` structure throws errors the url can be overriden by:
* setting the variable `google_bots_url` to a valid URL
