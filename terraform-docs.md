# terraform-docs

(Generate with `terraform-docs markdown --anchor=false --html=false --indent=3 --output-file=terraform-docs.md .`)

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| terraform | >=1.3.0 |
| aws | ~> 4.0 |
| http | ~> 3.0 |

### Providers

| Name | Version |
|------|---------|
| aws | 4.32.0 |
| http | 3.1.0 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [aws_athena_database.waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_database) | resource |
| [aws_athena_named_query.blocked_requests](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_named_query) | resource |
| [aws_athena_named_query.first_logs_query](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_named_query) | resource |
| [aws_athena_named_query.requests_per_client_ip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_named_query) | resource |
| [aws_athena_named_query.waf_logs_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_named_query) | resource |
| [aws_athena_workgroup.waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_workgroup) | resource |
| [aws_s3_bucket.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_acl.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_acl) | resource |
| [aws_s3_bucket_lifecycle_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_wafv2_ip_set.allowed_ips](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_ip_set) | resource |
| [aws_wafv2_ip_set.allowed_ips_v6](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_ip_set) | resource |
| [aws_wafv2_ip_set.self](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_ip_set) | resource |
| [aws_wafv2_regex_pattern_set.string](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_regex_pattern_set) | resource |
| [aws_wafv2_web_acl.waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_logging_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [http_http.googlebot](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [http_http.oracle](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [http_http.parsely_ip_list](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| allowed\_ips | The IPv4 to allow | `set(string)` | `[]` | no |
| allowed\_ips\_v6 | The IPv6 to allow | `set(string)` | `[]` | no |
| allowed\_partners | Allowed partner host headers | ```list(object({ name = string priority = number hostname = set(string) }))``` | `[]` | no |
| aws\_managed\_rules | AWS managed rules for WAF to set. Not applicable for var.waf\_scope = REGIONAL | ```list(object({ name = string priority = number }))``` | `[]` | no |
| aws\_managed\_rules\_labels | Labels set by the COUNT rules that want to be rate-limited. Not applicable for var.waf\_scope = REGIONAL | `list(string)` | ```[ "awswaf:managed:aws:anonymous-ip-list:AnonymousIPList", "awswaf:managed:aws:anonymous-ip-list:HostingProviderIPList" ]``` | no |
| aws\_managed\_rules\_limit | The rate limit for all requests matching the `aws_managed_rules_labels`. Not applicable for var.waf\_scope = REGIONAL | `number` | `750` | no |
| block\_articles | The list of articles to block from some countries | ```list(object({ name = string priority = number articles = set(string) country_code = set(string) }))``` | `[]` | no |
| block\_regex\_pattern | The list of regex to block from some countries | ```map(object({ description = string priority = number country_code = set(string) regex_string = string }))``` | `{}` | no |
| block\_uri\_path\_string | Allow to block specific strings, defining the positional constraint of the string. | ```list(object({ name = string priority = optional(number, 4) positional_constraint = optional(string, "EXACTLY") # Valid Values: EXACTLY | STARTS_WITH | ENDS_WITH | CONTAINS | CONTAINS_WORD search_string = string }))``` | `[]` | no |
| count\_ch\_limit | The limit for the 'emergency button' rule - not applied if set to 0 | `number` | `300` | no |
| count\_ch\_priority | The priority for counting requests coming from CH | `number` | `40` | no |
| country\_rates | Countries blocking limits | ```list(object({ name = string limit = number priority = number country_code = set(string) }))``` | `[]` | no |
| deploy\_athena\_queries | Enables the deployment of the athena presaved queries to easily access the logs generated by waf | `bool` | `true` | no |
| enable\_count\_ch\_requests | Whether to enable a rule for counting the requests coming from Switzerland | `bool` | `false` | no |
| enable\_google\_bots\_whitelist | Whitelist the Google bots IPs. (https://developers.google.com/search/apis/ipranges/googlebot.json) | `bool` | `true` | no |
| enable\_logging | Enable waf logs. | `bool` | `false` | no |
| enable\_oracle\_crawler\_whitelist | Whitelist the Oracle Data Cloud Crawler IPs. (https://www.oracle.com/corporate/acquisitions/grapeshot/crawler.html) | `bool` | `true` | no |
| enable\_parsely\_crawlers\_whitelist | Whitelist the Parse.ly crawler IPs. (https://www.parse.ly/help/integration/crawler) | `bool` | `false` | no |
| everybody\_else\_limit | The blocking limit for all countries which are not covered by country\_rates - not applied if it set to 0 | `number` | `0` | no |
| google\_bots\_url | The url where to get the Google bots IPs list. In case of problems the default url can be overridden. | `string` | `"https://developers.google.com/search/apis/ipranges/googlebot.json"` | no |
| logs\_bucket\_name | Override the default bucket name for waf logs. Default name: `aws-waf-logs-<lower(var.waf_scope)>-<data.aws_caller_identity.current.account_id>` | `string` | `null` | no |
| oracle\_data\_cloud\_crawlers\_url | The url whre to get the Oracle Data Cloud Crawler IPs list. In case of problems the default url can be overridden. | `string` | `"https://www.oracle.com/corporate/acquisitions/grapeshot/crawler.html"` | no |
| parsely\_crawlers\_url | The url where to get the Parse.ly crawler IPs list. In case of problems the default url can be overridden. | `string` | `"https://www.parse.ly/static/data/crawler-ips.json"` | no |
| search\_limitation | The blocking limit for calls to /search for countries NOT in the country\_code list - this value needs to be lower than the everybody else - not applied if the limit is set to 0 | ```object({ limit = number country_code = set(string) })``` | ```{ "country_code": [], "limit": 0 }``` | no |
| self\_ips | The IP from own AWS account (NAT gateways) | `set(string)` | `[]` | no |
| waf\_name | The name for WAF | `string` | `"cloudfront-waf"` | no |
| waf\_scope | The scope of the deployed waf. Available options [CLOUDFRONT,REGIONAL] | `string` | `"CLOUDFRONT"` | no |
| whitelisted\_txgroup\_ip\_ranges | List of TX Group IP ranges to be whitelisted. Set to empty list to disable the whitelisting | `list(string)` | ```[ "145.234.0.0/16" ]``` | no |

### Outputs

| Name | Description |
|------|-------------|
| google\_bots | List of Google bots whitelisted |
| oracle\_data\_cloud\_crawlers | List of Oracle Data CLoud Crawlers whitelisted |
| web\_acl\_arn | Web ACL arn |
| web\_acl\_id | WAF arn used with the cloudfront |
<!-- END_TF_DOCS -->
