# Waf Module

This module provides WAF resources to attach to cloudfront distribution or load balancer

## Core concepts

This module create the AWS WAF Web ACLs and AWS WAF IP sets necessary to protect a Cloudfront or LB.

It's designed to propose the following rules:

| Priority (default) | Rule Name | Notes |
|---|---|---|
| `var.blocked_headers.priority` (0) | block_based_on_headers | |
| `var.whitelist_group_priority` (1) | whitelist_group | Whitelists bots by downloading IP lists on apply based on `var.google_whitelist_config`, `var.parsely_whitelist_config`, `var.k6_whitelist_config`. Also whitelists custom IP lists defined in `var.ip_whitelisting` |
| `var.limit_search_requests_by_countries.priority` (2) | limit_search_requests_by_countries | Rate limits requests to path `/search` by country |
| defined in `var.block_uri_path_string[*].priority` | block_uri_path_string | |
| defined in `var.block_articles[*].priority` | block_articles | |
| defined in `var.block_regex_pattern[*].priority` | block_regex_pattern | |
| `var.rate_limit_failsafe_priority` (42) | Rate_limit_everything_apart_from_CH | Failsafe switch in case of attack. Change "count" to "block" in the console to rate limit all countries except Switzerland |
| `var.count_requests_from_ch.priority` (43) | count_requests_from_ch | |
| `var.whitelisted_headers.priority` (44) | whitelist_based_on_headers | |
| defined in `var.aws_managed_rule_groups[*].priority` | AWS Managed rule groups | Each group counts and labels requests; labels can then be acted on by the aws_managed_rule_labels rule. Refer to the [AWS docs](https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-list.html). Not applicable for `waf_scope = REGIONAL` |
| `var.aws_managed_rule_labels_priority` (60) | AWS managed rule labels rate limit | For each label a configurable action can be applied: block, captcha, or challenge — with optional rate limiting |
| defined in `var.country_rates[*].priority` | country_rates | Geographical rate limit rules, deployed as chunked rule groups (see below) |
| `var.everybody_else_config.priority` (80) | everybody_else_config | Rate limit for all country codes not covered by `country_rates`. Set `limit = 0` to disable |
| `var.country_count_rules_priority` (90) | country_count_rules | Rule group that counts requests from specific countries |
| `var.shield_mitigation.priority` (10,000,000) | ShieldMitigationRuleGroup | AWS Shield Advanced automatic mitigation rule group (see below). Only deployed when `var.shield_mitigation.enabled = true` |

## Country rates — chunked rule groups

The `country_rates` rules are deployed inside WAF rule groups rather than directly in the Web ACL. Because each WAF rule group has a fixed capacity, the module automatically splits `var.country_rates` into chunks of 4 and creates one rule group per chunk (`country_rate_rules_0`, `country_rate_rules_1`, …). This allows you to define an unlimited number of country rate rules without hitting WAF capacity limits.

Each entry in `var.country_rates` maps to one rate-based rule inside the appropriate chunk group. The `priority` field is scoped to the rule group (not the Web ACL), so priorities only need to be unique within `var.country_rates` itself.

## AWS Shield Advanced integration

When [AWS Shield Advanced automatic application layer DDoS mitigation](https://docs.aws.amazon.com/waf/latest/developerguide/ddos-automatic-app-layer-response-rg.html) is enabled on a protected resource, Shield creates and manages a **single WAF rule group per Web ACL**. Even if multiple resources (e.g. multiple CloudFront distributions) share the same ACL and all have automatic mitigation enabled, Shield still creates only one rule group for that ACL. This module references that rule group via `var.shield_mitigation`:

```hcl
shield_mitigation = {
  enabled        = true
  rule_group_arn = "<arn-provided-by-shield>"  # available after Shield has created the group
  priority       = 10000000                    # default — runs after all your own rules
  action         = "count"                     # default — observe only; set to "none" to let Shield block
}
```

- `rule_group_arn` is required when `enabled = true`; Shield creates it once automatic mitigation is activated on any resource associated with this ACL.
- `action` controls the WAF `override_action` applied to the Shield rule group:
  - `"count"` (default) — all requests are counted but never blocked by this rule group. Use this to observe Shield's detections without impact.
  - `"none"` — the rule group's own actions apply, meaning Shield will block traffic it identifies as a DDoS attack. Switch to this when you are under active attack and have validated Shield's detections.
- The default priority `10,000,000` is the value AWS itself assigns to Shield rules so they evaluate after all your own rules. Do not use this priority for any other rule.
- If you have engaged the AWS Shield Response Team (SRT), they may add temporary rules at **low priority numbers** during an active DDoS event. Leave headroom at the low end of your priority range so the SRT has room to insert rules without conflicts.

### Enabling automatic mitigation per resource

`aws_shield_application_layer_automatic_response` is a **per-resource** Terraform resource — it must be declared for each CloudFront distribution or ALB you want to protect, in the stack that manages those resources (not in this module). This module only needs to know the resulting rule group ARN.

```hcl
# In your service/distribution stack — one per protected resource
resource "aws_shield_application_layer_automatic_response" "this" {
  resource_arn = aws_cloudfront_distribution.this.arn
  action { count {} } # start with count; switch to block when confident
}
```

### Finding the rule group ARN

The ARN is only available after Shield has created the rule group. You can find it via:

- **AWS Console** — Shield Advanced → Protected resources → select your resource → "Automatic application layer DDoS mitigation" section.
- **AWS CLI:**
  ```bash
  aws wafv2 list-rule-groups --scope CLOUDFRONT --region us-east-1
  ```
  Look for a rule group named `ShieldMitigationRuleGroup_<account-id>_<web-acl-id>_<uuid>`.
- **Terraform data source** — to avoid hardcoding the ARN:
  ```hcl
  data "aws_wafv2_rule_group" "shield" {
    name  = "ShieldMitigationRuleGroup_<account-id>_<web-acl-id>_<uuid>"
    scope = "CLOUDFRONT"
  }

  shield_mitigation = {
    enabled        = true
    rule_group_arn = data.aws_wafv2_rule_group.shield.arn
  }
  ```

> **Important:** Shield automatically adds the rule group to your ACL when mitigation is first enabled. If you run `terraform apply` before declaring `shield_mitigation`, Terraform will remove the Shield rule group from the ACL. Always add the ARN to your config before the next apply.

The typical workflow is:
1. Declare `aws_shield_application_layer_automatic_response` for each protected resource in the service stack and apply.
2. Shield creates the rule group and adds it to the ACL automatically.
3. Retrieve the ARN (console, CLI, or data source) and add it to `var.shield_mitigation` in this module.
4. Run `terraform apply` — Terraform now manages the rule group and will no longer remove it.

## Waf logging

The module will also deploy several `AWS Athena` resources by default. These includes:

* an `Athena workgroup`
* an `Athena database`
* several `Athena queries`
* and an S3 bucket where waf logs will be saved if activated.

To activate waf logs set the `var.enable_logging` to `true` (`false` by default).

### Query WAF logs

In order to be able to query WAF logs saved on the S3 Bucket, we need to use the AWS Athena service:

* Once Logs have been activated we need to connect to Athena service via AWS console.
* Select the correct workgroup
* Here among the list of "Saved queries", you can find a query named "partition-projection-table-creation"
* If a table with the same name already exists, please delete it
* Set the query parameters as described in the query comments and run it
* Now a partition table is available and queries can be executed against the WAF logs stored on S3

Note: whenever WAF attachment changes, the partition projection table has to be deleted and recreated by updating the correct S3 bucket path. The table is created through the query partition-projection-table-creation

## How do you use this module?

Create the following new module block with the desired parameters (in `waf.tf`?)

INFO: for cloudfront the aws provider should be in us-west-1 region.

```HCL
module "waf" {
  source = "tx-pts-dai/waf/aws"
  version = "~> 0.x"
  providers = {
    aws = aws.us
  }
}
```

For a list of all variables please refer to [the terraform-docs](terraform-docs.md) of the module

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

### REGIONAL waf notes

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

## Problems with the Google bots ?

If the google bot jsonecode throws errors it can be disabled by:

* setting `var.google_whitelist_config.enable = false`

If the `data.http.googlebot` structure throws errors the url can be overridden by:

* setting the variable `var.google_whitelist_config.url` to a valid URL

Similar settings exist for `var.parsely_whitelist_config` and `var.k6_whitelist_config` as well.

## How to setup parallel WAFs ?
If you need to deploy more than one WAF in the same account, you can choose between letting each waf managing their own logs, or you can reuse an existing bucket and pass it as a parameter.

If you do create a bucket for logs outside of this module, and use the alternative bucket, you need to set up the following resources on the bucket :
```
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
  bucket = aws_s3_bucket.logs.id
  rule {
    id = "waf-logs"
    expiration {
      days = var.waf_logs_retention
    }
    status = "Enabled"
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_athena_database.waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_database) | resource |
| [aws_athena_named_query.blocked_requests](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_named_query) | resource |
| [aws_athena_named_query.count_group_by](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_named_query) | resource |
| [aws_athena_named_query.first_logs_query](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_named_query) | resource |
| [aws_athena_named_query.per_ip_blocked_requests](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_named_query) | resource |
| [aws_athena_named_query.requests_per_client_ip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_named_query) | resource |
| [aws_athena_named_query.waf_logs_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_named_query) | resource |
| [aws_athena_workgroup.waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_workgroup) | resource |
| [aws_s3_bucket.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_acl.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_acl) | resource |
| [aws_s3_bucket_lifecycle_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_wafv2_ip_set.whitelist](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_ip_set) | resource |
| [aws_wafv2_regex_pattern_set.string](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_regex_pattern_set) | resource |
| [aws_wafv2_rule_group.aws_managed_rule_labels](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_rule_group) | resource |
| [aws_wafv2_rule_group.country_count_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_rule_group) | resource |
| [aws_wafv2_rule_group.country_rate_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_rule_group) | resource |
| [aws_wafv2_rule_group.whitelist](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_rule_group) | resource |
| [aws_wafv2_web_acl.waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_logging_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_s3_bucket.log_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alternative_logs_bucket_name"></a> [alternative\_logs\_bucket\_name](#input\_alternative\_logs\_bucket\_name) | Override the default bucket destination for waf logs. If 'deploy\_logs' is set to false, this variable must be set. | `string` | `null` | no |
| <a name="input_aws_managed_rule_groups"></a> [aws\_managed\_rule\_groups](#input\_aws\_managed\_rule\_groups) | AWS Managed Rule Groups counting and labeling requests. The labels applied by these groups can be specified in aws\_managed\_rule\_labels to rate limit requests. Available groups are described here https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-list.html. Not applicable for var.waf\_scope = REGIONAL | <pre>list(object({<br/>    name     = string<br/>    priority = number<br/>  }))</pre> | <pre>[<br/>  {<br/>    "name": "AWSManagedRulesAnonymousIpList",<br/>    "priority": 50<br/>  },<br/>  {<br/>    "name": "AWSManagedRulesAmazonIpReputationList",<br/>    "priority": 51<br/>  }<br/>]</pre> | no |
| <a name="input_aws_managed_rule_labels"></a> [aws\_managed\_rule\_labels](#input\_aws\_managed\_rule\_labels) | AWS Managed rules labels to rate limit. The group using this label must be specified in aws\_managed\_rule\_groups in order to apply the label to incoming requests. Not applicable for var.waf\_scope = REGIONAL | <pre>list(object({<br/>    name                 = string<br/>    labels               = list(string)<br/>    enable_rate_limiting = optional(bool, true)      # if false all requests will be directly blocked<br/>    limit                = optional(number, 500)     # only used if enable_rate_limiting = true<br/>    action               = optional(string, "block") # possible actions: count, block, captcha, challenge<br/>    immunity_seconds     = optional(number, 300)     # only used if action is captcha (for challenge it's not currently allowed in tf, see waf.tf for more details). Immunity time in seconds after successfully passing a challenge<br/>    priority             = number<br/>  }))</pre> | <pre>[<br/>  {<br/>    "labels": [<br/>      "awswaf:managed:aws:anonymous-ip-list:AnonymousIPList",<br/>      "awswaf:managed:aws:amazon-ip-list:AWSManagedIPReputationList",<br/>      "awswaf:managed:aws:amazon-ip-list:AWSManagedReconnaissanceList",<br/>      "awswaf:managed:aws:amazon-ip-list:AWSManagedIPDDoSList"<br/>    ],<br/>    "name": "aws_managed_rule_low_limit",<br/>    "priority": 60<br/>  },<br/>  {<br/>    "labels": [<br/>      "awswaf:managed:aws:anonymous-ip-list:HostingProviderIPList"<br/>    ],<br/>    "limit": 750,<br/>    "name": "aws_managed_rule_high_limit",<br/>    "priority": 61<br/>  }<br/>]</pre> | no |
| <a name="input_aws_managed_rule_labels_priority"></a> [aws\_managed\_rule\_labels\_priority](#input\_aws\_managed\_rule\_labels\_priority) | Priority of the aws\_managed\_rule\_labels rule group rule in the WAF ACL. Must not conflict with any other rule priority. | `number` | `60` | no |
| <a name="input_block_articles"></a> [block\_articles](#input\_block\_articles) | The list of articles to block from some country\_codes | <pre>list(object({<br/>    name          = string<br/>    priority      = number<br/>    articles      = set(string)<br/>    country_codes = set(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_block_regex_pattern"></a> [block\_regex\_pattern](#input\_block\_regex\_pattern) | Regex to block articles coming from a list of country\_codes | <pre>map(object({<br/>    description   = string<br/>    priority      = number<br/>    country_codes = set(string)<br/>    regex_string  = string<br/>  }))</pre> | `{}` | no |
| <a name="input_block_uri_path_string"></a> [block\_uri\_path\_string](#input\_block\_uri\_path\_string) | Allow to block specific strings, defining the positional constraint of the string. | <pre>list(object({<br/>    name                  = string<br/>    priority              = number<br/>    positional_constraint = optional(string, "EXACTLY")<br/>    search_string         = string<br/>  }))</pre> | `[]` | no |
| <a name="input_blocked_headers"></a> [blocked\_headers](#input\_blocked\_headers) | Headers to block on. Set to null to disable. 'rules' is a list of header/value match conditions; 'priority' sets the WAF ACL rule priority. | <pre>object({<br/>    priority = optional(number, 0)<br/>    rules = list(object({<br/>      header            = string<br/>      value             = string<br/>      string_match_type = optional(string, "EXACTLY") # possible values: EXACTLY, STARTS_WITH, ENDS_WITH, CONTAINS, CONTAINS_WORD<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_count_requests_from_ch"></a> [count\_requests\_from\_ch](#input\_count\_requests\_from\_ch) | If enabled, deploys a rule that counts requests from Switzerland. | <pre>object({<br/>    enabled  = optional(bool, false)<br/>    priority = optional(number, 43)<br/>  })</pre> | `{}` | no |
| <a name="input_country_count_rules"></a> [country\_count\_rules](#input\_country\_count\_rules) | Enable the deployment of rules that count the requests from specific countries. The priority defined here is the one internal to the rule group. | <pre>list(object({<br/>    name          = string<br/>    limit         = number<br/>    priority      = number<br/>    country_codes = set(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_country_count_rules_priority"></a> [country\_count\_rules\_priority](#input\_country\_count\_rules\_priority) | Priority of the country\_count\_rules rule group rule in the WAF ACL. Must not conflict with any other rule priority. | `number` | `90` | no |
| <a name="input_country_rates"></a> [country\_rates](#input\_country\_rates) | List of limits for groups of countries. | <pre>list(object({<br/>    name             = string<br/>    limit            = number<br/>    priority         = number<br/>    action           = optional(string, "block") # possible actions: block, captcha, challenge<br/>    immunity_seconds = optional(number, 300)     # only used if action is captcha (for challenge it's not currently allowed in tf, see waf.tf for more details). Immunity time in seconds after successfully passing a challenge<br/>    country_codes    = set(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_deploy_logs"></a> [deploy\_logs](#input\_deploy\_logs) | Enables the deployment of the s3 bucket to store the waf logs. Also enables the deployment of the athena pre-saved queries to easily access the logs generated by waf | `bool` | `true` | no |
| <a name="input_enable_logging"></a> [enable\_logging](#input\_enable\_logging) | Enables or disable the logging (independent of the buckets/athena) | `bool` | `false` | no |
| <a name="input_everybody_else_config"></a> [everybody\_else\_config](#input\_everybody\_else\_config) | Priority and limit for all country\_codes not covered by country\_rates. Set limit to 0 to disable the rule. | <pre>object({<br/>    limit    = optional(number, 0)<br/>    priority = optional(number, 80)<br/>  })</pre> | `{}` | no |
| <a name="input_ip_whitelisting"></a> [ip\_whitelisting](#input\_ip\_whitelisting) | Map of configurations for whitelisting IP lists. Populate this using the ip\_list\_fetcher sub-module or with static CIDRs. Use 'insert\_header' to add custom headers to whitelisted requests (headers are prefixed automatically with `x-amzn-waf-`). | <pre>map(object({<br/>    ips                = list(string)<br/>    ip_address_version = string # possible values: IPV4, IPV6<br/>    priority           = number<br/>    insert_header      = optional(map(string), null)<br/>  }))</pre> | `{}` | no |
| <a name="input_limit_search_requests_by_countries"></a> [limit\_search\_requests\_by\_countries](#input\_limit\_search\_requests\_by\_countries) | Limit requests on the path /search that comes from the specified list of country\_codes. Rule not deployed if list of countries is empty. | <pre>object({<br/>    priority      = optional(number, 2)<br/>    limit         = optional(number, 100)<br/>    country_codes = set(string)<br/>  })</pre> | <pre>{<br/>  "country_codes": [],<br/>  "limit": 100<br/>}</pre> | no |
| <a name="input_logo_path"></a> [logo\_path](#input\_logo\_path) | Company logo path (for 429 pages) | `string` | `""` | no |
| <a name="input_logs_bucket_name_override"></a> [logs\_bucket\_name\_override](#input\_logs\_bucket\_name\_override) | Override the default bucket name for waf logs. Default name: `aws-waf-logs-<lower(var.waf_scope)>-<data.aws_caller_identity.current.account_id>` | `string` | `null` | no |
| <a name="input_rate_limit_failsafe_priority"></a> [rate\_limit\_failsafe\_priority](#input\_rate\_limit\_failsafe\_priority) | Priority of the rate\_limit\_everything\_apart\_from\_CH failsafe rule in the WAF ACL. Must not conflict with any other rule priority. | `number` | `42` | no |
| <a name="input_shield_mitigation"></a> [shield\_mitigation](#input\_shield\_mitigation) | Reference the Shield Advanced automatic mitigation rule group in the WAF ACL. AWS Shield Advanced creates and manages this rule group when automatic application layer DDoS mitigation is enabled on the protected resource — this variable lets you explicitly control its priority rather than letting Shield place it automatically. rule\_group\_arn must be provided when enabled; it is available after Shield has created the group. Priority defaults to 10,000,000, the value AWS assigns so that the Shield rule runs after all your own rules. Do not use priority 10,000,000 for any other rule. See https://docs.aws.amazon.com/waf/latest/developerguide/ddos-automatic-app-layer-response-rg.html | <pre>object({<br/>    enabled        = optional(bool, false)<br/>    priority       = optional(number, 10000000)<br/>    rule_group_arn = optional(string, null)<br/>    action         = optional(string, "count") # possible values: count (observe only), none (use rule group's own actions — blocks when Shield detects an attack)<br/>  })</pre> | `{}` | no |
| <a name="input_waf_logs_retention"></a> [waf\_logs\_retention](#input\_waf\_logs\_retention) | Retention time (in days) of waf logs | `number` | `7` | no |
| <a name="input_waf_name"></a> [waf\_name](#input\_waf\_name) | The name for WAF | `string` | `"cloudfront-waf"` | no |
| <a name="input_waf_scope"></a> [waf\_scope](#input\_waf\_scope) | The scope of the deployed waf. Available options [CLOUDFRONT,REGIONAL] | `string` | `"CLOUDFRONT"` | no |
| <a name="input_whitelist_group_priority"></a> [whitelist\_group\_priority](#input\_whitelist\_group\_priority) | Priority of the whitelist rule group rule in the WAF ACL. Must not conflict with any other rule priority. | `number` | `1` | no |
| <a name="input_whitelisted_headers"></a> [whitelisted\_headers](#input\_whitelisted\_headers) | Map of header => value to be whitelisted. Set to null to disable the whitelisting | <pre>object({<br/>    priority          = optional(number, 44)<br/>    headers           = map(string)<br/>    string_match_type = optional(string, "EXACTLY") # possible values: EXACTLY, STARTS_WITH, ENDS_WITH, CONTAINS, CONTAINS_WORD<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_logs_bucket_arn"></a> [logs\_bucket\_arn](#output\_logs\_bucket\_arn) | Logs bucket arn |
| <a name="output_logs_bucket_name"></a> [logs\_bucket\_name](#output\_logs\_bucket\_name) | Logs bucket name |
| <a name="output_web_acl_arn"></a> [web\_acl\_arn](#output\_web\_acl\_arn) | Web ACL arn |
| <a name="output_web_acl_id"></a> [web\_acl\_id](#output\_web\_acl\_id) | WAF arn used with the cloudfront |
<!-- END_TF_DOCS -->

## Authors

Module is maintained by [Alfredo Gottardo](https://github.com/AlfGot), [David Beauvererd](https://github.com/Davidoutz), [Davide Cammarata](https://github.com/DCamma), [Francisco Ferreira](https://github.com/cferrera) [Demetrio Carrara](https://github.com/sgametrio), [Roland Bapst](https://github.com/rbapst-tamedia) and [Samuel Wibrow](https://github.com/swibrow)

## License

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.
