variable "waf_name" {
  default     = "cloudfront-waf"
  description = "The name for WAF"
  type        = string
}

variable "logo_path" {
  default     = ""
  description = "Company logo path (for 429 pages)"
  type        = string
}

variable "waf_scope" {
  default     = "CLOUDFRONT"
  description = "The scope of the deployed waf. Available options [CLOUDFRONT,REGIONAL]"
  type        = string
  validation {
    condition     = contains(["CLOUDFRONT", "REGIONAL"], var.waf_scope)
    error_message = "var.waf_scope can be either CLOUDFRONT or REGIONAL"
  }
}

variable "waf_logs_retention" {
  default     = 7
  description = "Retention time (in days) of waf logs"
  type        = number
}

## Variables for WAF Rules

variable "ip_whitelisting" {
  description = "Map of configurations for whitelisting IP lists. Populate this using the ip_list_fetcher sub-module or with static CIDRs. Use 'insert_header' to add custom headers to whitelisted requests (headers are prefixed automatically with `x-amzn-waf-`)."
  default     = {}
  type = map(object({
    ips                = list(string)
    ip_address_version = string # possible values: IPV4, IPV6
    priority           = number
    insert_header      = optional(map(string), null)
  }))
  validation {
    condition = alltrue(
      [for item in var.ip_whitelisting :
        (
          item.ip_address_version == "IPV4" || item.ip_address_version == "IPV6") && (
          item.ip_address_version == "IPV6" && alltrue([for ip in item.ips : can(regex("^[0-9a-fA-F:]*/\\d{1,3}", ip))]) ||
          item.ip_address_version == "IPV4" && alltrue([for ip in item.ips : can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}/\\d{1,2}", ip))])
      )]
    )
    error_message = "var.ip_whitelisting.ip_address_version must be either IPV4 or IPV6 with mask. Example: ['1.1.1.1/16'] for IPV4 and ['2001:db8::/32'] for IPV6"
  }
}

variable "whitelist_group_priority" {
  description = "Priority of the whitelist rule group rule in the WAF ACL. Must not conflict with any other rule priority."
  type        = number
  default     = 1
}

variable "whitelisted_headers" {
  description = "Map of header => value to be whitelisted. Set to null to disable the whitelisting"
  type = object({
    priority          = optional(number, 44)
    headers           = map(string)
    string_match_type = optional(string, "EXACTLY") # possible values: EXACTLY, STARTS_WITH, ENDS_WITH, CONTAINS, CONTAINS_WORD
  })
  default = null
}

variable "blocked_headers" {
  description = "Headers to block on. Set to null to disable. 'rules' is a list of header/value match conditions; 'priority' sets the WAF ACL rule priority."
  type = object({
    priority = optional(number, 0)
    rules = list(object({
      header            = string
      value             = string
      string_match_type = optional(string, "EXACTLY") # possible values: EXACTLY, STARTS_WITH, ENDS_WITH, CONTAINS, CONTAINS_WORD
    }))
  })
  default = null
}

variable "aws_managed_rule_groups" {
  description = "AWS Managed Rule Groups counting and labeling requests. The labels applied by these groups can be specified in aws_managed_rule_labels to rate limit requests. Available groups are described here https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-list.html. Not applicable for var.waf_scope = REGIONAL"
  type = list(object({
    name     = string
    priority = number
  }))
  default = [
    {
      name     = "AWSManagedRulesAnonymousIpList" # Full list of labels from this group: https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-ip-rep.html
      priority = 50
    },
    {
      name     = "AWSManagedRulesAmazonIpReputationList" # Full list of labels from this group: https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-ip-rep.html
      priority = 51
    }
  ]
}

variable "aws_managed_rule_labels" {
  description = "AWS Managed rules labels to rate limit. The group using this label must be specified in aws_managed_rule_groups in order to apply the label to incoming requests. Not applicable for var.waf_scope = REGIONAL"
  type = list(object({
    name                 = string
    labels               = list(string)
    enable_rate_limiting = optional(bool, true)      # if false all requests will be directly blocked
    limit                = optional(number, 500)     # only used if enable_rate_limiting = true
    action               = optional(string, "block") # possible actions: count, block, captcha, challenge
    immunity_seconds     = optional(number, 300)     # only used if action is captcha (for challenge it's not currently allowed in tf, see waf.tf for more details). Immunity time in seconds after successfully passing a challenge
    priority             = number
  }))
  default = [
    {
      name     = "aws_managed_rule_low_limit"
      labels   = ["awswaf:managed:aws:anonymous-ip-list:AnonymousIPList", "awswaf:managed:aws:amazon-ip-list:AWSManagedIPReputationList", "awswaf:managed:aws:amazon-ip-list:AWSManagedReconnaissanceList", "awswaf:managed:aws:amazon-ip-list:AWSManagedIPDDoSList"]
      priority = 60
    },
    {
      name     = "aws_managed_rule_high_limit"
      labels   = ["awswaf:managed:aws:anonymous-ip-list:HostingProviderIPList"]
      limit    = 750
      priority = 61
    }
  ]
  validation {
    condition     = length(var.aws_managed_rule_labels) <= 4
    error_message = "var.aws_managed_rule_labels can have a max length of 4."
  }
  validation {
    condition     = alltrue([for rule in var.aws_managed_rule_labels : contains(["count", "block", "captcha", "challenge"], rule.action)])
    error_message = "var.aws_managed_rule_labels.action must be either count, block, captcha or challenge"
  }
}

variable "aws_managed_rule_labels_priority" {
  description = "Priority of the aws_managed_rule_labels rule group rule in the WAF ACL. Must not conflict with any other rule priority."
  type        = number
  default     = 60
}

variable "count_requests_from_ch" {
  description = "If enabled, deploys a rule that counts requests from Switzerland."
  type = object({
    enabled  = optional(bool, false)
    priority = optional(number, 43)
  })
  default = {}
}

variable "country_rates" {
  default     = []
  description = "List of limits for groups of countries."
  type = list(object({
    name             = string
    limit            = number
    priority         = number
    action           = optional(string, "block") # possible actions: block, captcha, challenge
    immunity_seconds = optional(number, 300)     # only used if action is captcha (for challenge it's not currently allowed in tf, see waf.tf for more details). Immunity time in seconds after successfully passing a challenge
    country_codes    = set(string)
  }))
  # Example
  # [
  #   { name         = "Group_1-CH"
  #     limit        = 50000
  #     country_codes = ["CH"]
  #     priority     = 30
  #   },
  #   { name         = "Group_2-DE_AT_FR"
  #     limit        = 4000
  #     country_codes = ["AT", "FR", "DE"]
  #     priority     = 31
  #   },
  #   ...
  #   { name         = "Very_slow"
  #     limit        = 100
  #     country_codes = ["AR", "BD", "BR", "KH", "CN", "CO", "EC", "IN", "ID", "MX", "NP", "PK", "RU", "SG", "TR", "UA", "AE", "ZM", "VN"]
  #     action       = "captcha"
  #     priority     = 35
  #   }
  # ]
}

variable "everybody_else_config" {
  description = "Priority and limit for all country_codes not covered by country_rates. Set limit to 0 to disable the rule."
  type = object({
    limit    = optional(number, 0)
    priority = optional(number, 80)
  })
  default = {}
}

variable "rate_limit_failsafe_priority" {
  description = "Priority of the rate_limit_everything_apart_from_CH failsafe rule in the WAF ACL. Must not conflict with any other rule priority."
  type        = number
  default     = 42
}

variable "limit_search_requests_by_countries" {
  default = {
    limit         = 100
    country_codes = []
  }
  description = "Limit requests on the path /search that comes from the specified list of country_codes. Rule not deployed if list of countries is empty."
  type = object({
    priority      = optional(number, 2)
    limit         = optional(number, 100)
    country_codes = set(string)
  })
}

variable "block_uri_path_string" {
  default     = []
  description = "Allow to block specific strings, defining the positional constraint of the string."
  type = list(object({
    name                  = string
    priority              = number
    positional_constraint = optional(string, "EXACTLY")
    search_string         = string
  }))
  validation {
    condition     = alltrue([for uri in var.block_uri_path_string : contains(["EXACTLY", "STARTS_WITH", "ENDS_WITH", "CONTAINS", "CONTAINS_WORD"], uri.positional_constraint)])
    error_message = "var.block_uri_path_string.positional_constraint must be one of: EXACTLY, STARTS_WITH, ENDS_WITH, CONTAINS, CONTAINS_WORD"
  }
}

variable "block_articles" {
  default     = []
  description = "The list of articles to block from some country_codes"
  type = list(object({
    name          = string
    priority      = number
    articles      = set(string)
    country_codes = set(string)
  }))
  # Example
  # [
  #   {
  #     name = "teci-439_Block_UK_Articles"
  #     articles = [
  #        "/story/21008846",
  #       "/story/11682567",
  #       "/story/10750748",
  #       "/story/20066183",
  #       "/story/29008823",
  #       "/story/17703007",
  #       "-930543720570"
  #     ]
  #     country_codes = ["GB"]
  #     priority     = 90
  #   },
  #   ...
  # ]
}

variable "block_regex_pattern" {
  default     = {}
  description = "Regex to block articles coming from a list of country_codes"
  type = map(object({
    description   = string
    priority      = number
    country_codes = set(string)
    regex_string  = string
  }))
  # Example
  # {
  #   List_of_Article_to_Block_from_USA = {
  #     description  = "List of Article to Block from USA"
  #     priority     = 110
  #     country_codes = ["US"]
  #     regex_string = "\\/content\\/(168154293778|199781524264|295880478843|456984065155|521246040231|548039927522|770770342355|850519746098|857984311223|875532264517|892009682269|961874634370)$"
  #   }
  # }
}

# LOGS
variable "deploy_logs" {
  description = "Enables the deployment of the s3 bucket to store the waf logs. Also enables the deployment of the athena pre-saved queries to easily access the logs generated by waf"
  default     = true
  type        = bool
}

variable "enable_logging" {
  description = "Enables or disable the logging (independent of the buckets/athena)"
  default     = false
  type        = bool
}

variable "alternative_logs_bucket_name" {
  description = "Override the default bucket destination for waf logs. If 'deploy_logs' is set to false, this variable must be set."
  default     = null
  type        = string
}

variable "logs_bucket_name_override" {
  description = "Override the default bucket name for waf logs. Default name: `aws-waf-logs-<lower(var.waf_scope)>-<data.aws_caller_identity.current.account_id>"
  default     = null
  type        = string
}

variable "country_count_rules" {
  description = "Enable the deployment of rules that count the requests from specific countries. The priority defined here is the one internal to the rule group."
  default     = []
  type = list(object({
    name          = string
    limit         = number
    priority      = number
    country_codes = set(string)
  }))
  # Example
  # [
  #   { name         = "count-CH"
  #     limit        = 50000
  #     country_codes = ["CH"]
  #     priority     = 90
  #   },
  #   { name         = "count-DE_AT_FR"
  #     limit        = 4000
  #     country_codes = ["AT", "FR", "DE"]
  #     priority     = 91
  #   },
  #   ...
  # ]
}

variable "country_count_rules_priority" {
  description = "Priority of the country_count_rules rule group rule in the WAF ACL. Must not conflict with any other rule priority."
  type        = number
  default     = 90
}

variable "shield_mitigation" {
  description = "Reference the Shield Advanced automatic mitigation rule group in the WAF ACL. AWS Shield Advanced creates and manages this rule group when automatic application layer DDoS mitigation is enabled on the protected resource — this variable lets you explicitly control its priority rather than letting Shield place it automatically. rule_group_arn must be provided when enabled; it is available after Shield has created the group. Priority defaults to 10,000,000, the value AWS assigns so that the Shield rule runs after all your own rules. Do not use priority 10,000,000 for any other rule. See https://docs.aws.amazon.com/waf/latest/developerguide/ddos-automatic-app-layer-response-rg.html"
  type = object({
    enabled        = optional(bool, false)
    priority       = optional(number, 10000000)
    rule_group_arn = optional(string, null)
  })
  default = {}
  validation {
    condition     = !var.shield_mitigation.enabled || var.shield_mitigation.rule_group_arn != null
    error_message = "var.shield_mitigation.rule_group_arn must be set when shield_mitigation.enabled is true."
  }
}
