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

variable "enable_google_bots_whitelist" {
  default     = true
  description = "Whitelist the Google bots IPs. (https://developers.google.com/search/apis/ipranges/googlebot.json)"
  type        = bool
}

variable "google_bots_url" {
  default     = "https://developers.google.com/search/apis/ipranges/googlebot.json"
  description = "The url where to get the Google bots IPs list. In case of problems the default url can be overridden."
  type        = string
}

variable "enable_parsely_crawlers_whitelist" {
  default     = false
  description = "Whitelist the Parse.ly crawler IPs. (https://www.parse.ly/help/integration/crawler)"
  type        = bool
}

variable "parsely_crawlers_url" {
  default     = "https://www.parse.ly/static/data/crawler-ips.json"
  description = "The url where to get the Parse.ly crawler IPs list. In case of problems the default url can be overridden."
  type        = string
}

variable "enable_k6_whitelist" {
  default     = false
  description = "Whitelist the K6 load generators IPs. (https://k6.io/docs/cloud/cloud-reference/cloud-ips/)"
  type        = bool
}

variable "k6_ip_ranges_url" {
  default     = "https://ip-ranges.amazonaws.com/ip-ranges.json"
  description = "The url where to get the K6 load generators IPs list. In case of problems the default url can be overridden."
  type        = string
}

## Variables for WAF Rules

variable "whitelisted_ips_v4" {
  default     = []
  description = "List of IP ranges to be whitelisted. Set to empty list to disable the whitelisting"
  type        = list(string)
  validation {
    condition = alltrue([
      for ip in var.whitelisted_ips_v4 : can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}/\\d{1,2}", ip))
    ])
    error_message = "whitelisted_ips_v4 must contain valid IP V4 ranges with mask. Example: ['1.1.1.1/16', '255.255.255.255/32']"
  }
}

variable "whitelisted_ips_v6" {
  default     = []
  description = "List of IP ranges to be whitelisted. Set to empty list to disable the whitelisting"
  type        = list(string)
  validation {
    # Not the "real" regexp for ipv6. The right one has around 1000 characters...
    condition = alltrue([
      for ip in var.whitelisted_ips_v6 : can(regex("^[0-9a-fA-F:]*/\\d{1,3}", ip))
    ])
    error_message = "whitelisted_ips_v6 must contain valid IP V6 ranges."
  }
}

variable "whitelisted_headers" {
  description = "Map of header => value to be whitelisted. Set to empty map to disable the whitelisting"
  type = object({
    headers           = map(string)
    string_match_type = optional(string, "EXACTLY") # possible values: EXACTLY, STARTS_WITH, ENDS_WITH, CONTAINS, CONTAINS_WORD
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
  validation {
    condition     = alltrue([for group in var.aws_managed_rule_groups : group.priority >= 50 && group.priority < 60])
    error_message = "var.aws_managed_rule_groups.priority must be between 10 and 19. var.aws_managed_rule_groups.override_group_action should be either count or block"
  }
}

variable "aws_managed_rule_labels" {
  description = "AWS Managed rules labels to rate limit. The group using this label must be specified in aws_managed_rule_groups in order to apply the label to incoming requests. Not applicable for var.waf_scope = REGIONAL"
  type = list(object({
    name                 = string
    labels               = list(string)
    enable_rate_limiting = optional(bool, true)      # if false all requests will be directly blocked
    limit                = optional(number, 500)     # only used if enable_rate_limiting = true
    action               = optional(string, "block") # possible actions: block, captcha, challenge
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
    condition     = alltrue([for rule in var.aws_managed_rule_labels : (rule.priority >= 60 && rule.priority < 64) && contains(["block", "captcha", "challenge"], rule.action)])
    error_message = "var.aws_managed_rule_labels.priority must be between 60 and 63. var.aws_managed_rule_labels.action must be either block, captcha or challenge"
  }
}

variable "count_requests_from_ch" {
  default     = false
  description = "If true it deploys a rule that counts requests from Switzerland with priority 4"
  type        = bool
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
  validation {
    condition     = alltrue([for uri in var.country_rates : uri.priority >= 70 && uri.priority < 80])
    error_message = "var.country_rates.priority must be between 70 and 80"
  }
}

variable "everybody_else_limit" {
  default     = 0
  description = "The limit for all country_codes which are not covered by country_rates - not applied if it set to 0"
  type        = number
}

variable "limit_search_requests_by_countries" {
  default = {
    limit         = 100
    country_codes = []
  }
  description = "Limit requests on the path /search that comes from the specified list of country_codes. Rule not deployed if list of countries is empty."
  type = object({
    limit         = optional(number, 100)
    country_codes = set(string)
  })
}

variable "block_uri_path_string" {
  default     = []
  description = "Allow to block specific strings, defining the positional constraint of the string."
  type = list(object({
    name                  = string
    priority              = optional(number, 1)
    positional_constraint = optional(string, "EXACTLY")
    search_string         = string
  }))
  validation {
    condition     = alltrue([for uri in var.block_uri_path_string : uri.priority >= 1 && uri.priority < 9 && contains(["EXACTLY", "STARTS_WITH", "ENDS_WITH", "CONTAINS", "CONTAINS_WORD"], uri.positional_constraint)])
    error_message = "var.block_uri_path_string.priority must be between 1 and 9"
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
  validation {
    condition     = alltrue([for uri in var.block_articles : uri.priority >= 10 && uri.priority < 19])
    error_message = "var.block_articles.priority must be between 10 and 19"
  }
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
  validation {
    condition     = alltrue([for uri in var.block_regex_pattern : uri.priority >= 20 && uri.priority < 30])
    error_message = "var.block_regex_pattern.priority must be between 20 and 29"
  }
}

# LOGS

variable "enable_logging" {
  description = "Enable waf logs."
  type        = bool
  default     = false
}

variable "deploy_athena_queries" {
  description = "Enables the deployment of the athena pre-saved queries to easily access the logs generated by waf"
  default     = true
  type        = bool
}

variable "logs_bucket_name_override" {
  description = "Override the default bucket name for waf logs. Default name: `aws-waf-logs-<lower(var.waf_scope)>-<data.aws_caller_identity.current.account_id>"
  default     = null
  type        = string
}
