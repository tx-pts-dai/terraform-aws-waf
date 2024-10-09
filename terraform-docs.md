# terraform-docs

(Generate with `terraform-docs markdown --anchor=false --html=false --indent=3 --output-file=terraform-docs.md .`)

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.3.0 |
| aws | >= 4.0 |
| http | >= 3.0 |

### Providers

| Name | Version |
|------|---------|
| aws | 5.70.0 |
| http | 3.4.5 |

### Modules

No modules.

### Resources

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
| [aws_wafv2_ip_set.whitelisted_ips_v4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_ip_set) | resource |
| [aws_wafv2_ip_set.whitelisted_ips_v6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_ip_set) | resource |
| [aws_wafv2_regex_pattern_set.string](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_regex_pattern_set) | resource |
| [aws_wafv2_rule_group.aws_managed_rule_labels](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_rule_group) | resource |
| [aws_wafv2_rule_group.country_rate_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_rule_group) | resource |
| [aws_wafv2_web_acl.waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_logging_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [http_http.googlebot](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [http_http.k6_load_generators](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [http_http.parsely_ip_list](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aws\_managed\_rule\_groups | AWS Managed Rule Groups counting and labeling requests. The labels applied by these groups can be specified in aws\_managed\_rule\_labels to rate limit requests. Available groups are described here https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-list.html. Not applicable for var.waf\_scope = REGIONAL | ```list(object({ name = string priority = number }))``` | ```[ { "name": "AWSManagedRulesAnonymousIpList", "priority": 50 }, { "name": "AWSManagedRulesAmazonIpReputationList", "priority": 51 } ]``` | no |
| aws\_managed\_rule\_labels | AWS Managed rules labels to rate limit. The group using this label must be specified in aws\_managed\_rule\_groups in order to apply the label to incoming requests. Not applicable for var.waf\_scope = REGIONAL | ```list(object({ name = string labels = list(string) enable_rate_limiting = optional(bool, true)      # if false all requests will be directly blocked limit = optional(number, 500)     # only used if enable_rate_limiting = true action = optional(string, "block") # possible actions: block, captcha, challenge immunity_seconds = optional(number, 300)     # only used if action is captcha (for challenge it's not currently allowed in tf, see waf.tf for more details). Immunity time in seconds after successfully passing a challenge priority = number }))``` | ```[ { "labels": [ "awswaf:managed:aws:anonymous-ip-list:AnonymousIPList", "awswaf:managed:aws:amazon-ip-list:AWSManagedIPReputationList", "awswaf:managed:aws:amazon-ip-list:AWSManagedReconnaissanceList", "awswaf:managed:aws:amazon-ip-list:AWSManagedIPDDoSList" ], "name": "aws_managed_rule_low_limit", "priority": 60 }, { "labels": [ "awswaf:managed:aws:anonymous-ip-list:HostingProviderIPList" ], "limit": 750, "name": "aws_managed_rule_high_limit", "priority": 61 } ]``` | no |
| block\_articles | The list of articles to block from some country\_codes | ```list(object({ name = string priority = number articles = set(string) country_codes = set(string) }))``` | `[]` | no |
| block\_regex\_pattern | Regex to block articles coming from a list of country\_codes | ```map(object({ description = string priority = number country_codes = set(string) regex_string = string }))``` | `{}` | no |
| block\_uri\_path\_string | Allow to block specific strings, defining the positional constraint of the string. | ```list(object({ name = string priority = optional(number, 1) positional_constraint = optional(string, "EXACTLY") search_string = string }))``` | `[]` | no |
| count\_requests\_from\_ch | If true it deploys a rule that counts requests from Switzerland with priority 4 | `bool` | `false` | no |
| country\_rates | List of limits for groups of countries. | ```list(object({ name = string limit = number priority = number action = optional(string, "block") # possible actions: block, captcha, challenge immunity_seconds = optional(number, 300)     # only used if action is captcha (for challenge it's not currently allowed in tf, see waf.tf for more details). Immunity time in seconds after successfully passing a challenge country_codes = set(string) }))``` | `[]` | no |
| deploy\_athena\_queries | Enables the deployment of the athena pre-saved queries to easily access the logs generated by waf | `bool` | `true` | no |
| enable\_google\_bots\_whitelist | Whitelist the Google bots IPs. (https://developers.google.com/search/apis/ipranges/googlebot.json) | `bool` | `true` | no |
| enable\_k6\_whitelist | Whitelist the K6 load generators IPs. (https://k6.io/docs/cloud/cloud-reference/cloud-ips/) | `bool` | `false` | no |
| enable\_logging | Enable waf logs. | `bool` | `false` | no |
| enable\_parsely\_crawlers\_whitelist | Whitelist the Parse.ly crawler IPs. (https://www.parse.ly/help/integration/crawler) | `bool` | `false` | no |
| everybody\_else\_limit | The limit for all country\_codes which are not covered by country\_rates - not applied if it set to 0 | `number` | `0` | no |
| google\_bots\_url | The url where to get the Google bots IPs list. In case of problems the default url can be overridden. | `string` | `"https://developers.google.com/search/apis/ipranges/googlebot.json"` | no |
| k6\_ip\_ranges\_url | The url where to get the K6 load generators IPs list. In case of problems the default url can be overridden. | `string` | `"https://ip-ranges.amazonaws.com/ip-ranges.json"` | no |
| limit\_search\_requests\_by\_countries | Limit requests on the path /search that comes from the specified list of country\_codes. Rule not deployed if list of countries is empty. | ```object({ limit = optional(number, 100) country_codes = set(string) })``` | ```{ "country_codes": [], "limit": 100 }``` | no |
| logo\_path | Company logo path (for 429 pages) | `string` | `""` | no |
| logs\_bucket\_name\_override | Override the default bucket name for waf logs. Default name: `aws-waf-logs-<lower(var.waf_scope)>-<data.aws_caller_identity.current.account_id>` | `string` | `null` | no |
| parsely\_crawlers\_url | The url where to get the Parse.ly crawler IPs list. In case of problems the default url can be overridden. | `string` | `"https://www.parse.ly/static/data/crawler-ips.json"` | no |
| waf\_logs\_retention | Retention time (in days) of waf logs | `number` | `7` | no |
| waf\_name | The name for WAF | `string` | `"cloudfront-waf"` | no |
| waf\_scope | The scope of the deployed waf. Available options [CLOUDFRONT,REGIONAL] | `string` | `"CLOUDFRONT"` | no |
| whitelisted\_headers | Map of header => value to be whitelisted. Set to empty map to disable the whitelisting | ```object({ headers = map(string) string_match_type = optional(string, "EXACTLY") # possible values: EXACTLY, STARTS_WITH, ENDS_WITH, CONTAINS, CONTAINS_WORD })``` | `null` | no |
| whitelisted\_ips\_v4 | List of IP ranges to be whitelisted. Set to empty list to disable the whitelisting | `list(string)` | `[]` | no |
| whitelisted\_ips\_v6 | List of IP ranges to be whitelisted. Set to empty list to disable the whitelisting | `list(string)` | `[]` | no |

### Outputs

| Name | Description |
|------|-------------|
| google\_bots | List of Google bots whitelisted |
| web\_acl\_arn | Web ACL arn |
| web\_acl\_id | WAF arn used with the cloudfront |
<!-- END_TF_DOCS -->
