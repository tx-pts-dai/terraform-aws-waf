variable "waf_name" {
  default     = "cloudfront-waf"
  description = "The name for WAF"
  type        = string
}

variable "waf_scope" {
  default     = "CLOUDFRONT"
  description = "The scope of the deployed waf. Available options [CLOUDFRONT,REGIONAL]"
  type        = string
}

variable "self_ips" {
  default     = []
  description = "The IP from own AWS account (NAT gateways)"
  type        = set(string)
}

variable "allowed_ips" {
  default     = []
  description = "The IPv4 to allow"
  type        = set(string)
}

variable "whitelisted_txgroup_ip_ranges" {
  default     = []
  description = "List of enterprise IP ranges to be whitelisted. Set to empty list to disable the whitelisting"
  type        = list(string)
}

variable "allowed_ips_v6" {
  default     = []
  description = "The IPv6 to allow"
  type        = set(string)
}

variable "waf_logs_retention" {
  default     = 7
  description = "Retention time (in days) of waf logs"
  type        = number
}

variable "block_uri_path_string" {
  default     = []
  description = "Allow to block specific strings, defining the positional constraint of the string."
  type = list(object({
    name                  = string
    priority              = optional(number, 4)
    positional_constraint = optional(string, "EXACTLY") # Valid Values: EXACTLY | STARTS_WITH | ENDS_WITH | CONTAINS | CONTAINS_WORD
    search_string         = string
  }))
}

variable "enable_oracle_crawler_whitelist" {
  default     = true
  description = "Whitelist the Oracle Data Cloud Crawler IPs. (https://www.oracle.com/corporate/acquisitions/grapeshot/crawler.html)"
  type        = bool
}

variable "oracle_data_cloud_crawlers_url" {
  default     = "https://www.oracle.com/corporate/acquisitions/grapeshot/crawler.html"
  description = "The url whre to get the Oracle Data Cloud Crawler IPs list. In case of problems the default url can be overridden."
  type        = string
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

variable "country_rates" {
  default     = []
  description = "Countries blocking limits"
  type = list(object({
    name         = string
    limit        = number
    priority     = number
    country_code = set(string)
  }))
  # Example
  # [
  #   { name         = "Group_1-CH"
  #     limit        = 50000
  #     country_code = ["CH"]
  #     priority     = 20
  #   },
  #   { name         = "Group_2-DE_AT_FR"
  #     limit        = 4000
  #     country_code = ["AT", "FR", "DE"]
  #     priority     = 21
  #   },
  #   ...
  #   { name         = "Very_slow"
  #     limit        = 100
  #     country_code = ["AR", "BD", "BR", "KH", "CN", "CO", "EC", "IN", "ID", "MX", "NP", "PK", "RU", "SG", "TR", "UA", "AE", "ZM", "VN"]
  #     priority     = 25
  #   }
  # ]
}

variable "everybody_else_limit" {
  default     = 0
  description = "The blocking limit for all countries which are not covered by country_rates - not applied if it set to 0"
  type        = number
}

variable "aws_managed_rules" {
  default     = []
  description = "AWS managed rules for WAF to set. Not applicable for var.waf_scope = REGIONAL"
  type = list(object({
    name     = string
    priority = number
  }))
}

variable "aws_managed_rules_limit" {
  default     = 750
  description = "The rate limit for all requests matching the `aws_managed_rules_labels`. Not applicable for var.waf_scope = REGIONAL"
  type        = number
}

variable "aws_managed_rules_labels" {
  default = [
    "awswaf:managed:aws:anonymous-ip-list:AnonymousIPList",
    "awswaf:managed:aws:anonymous-ip-list:HostingProviderIPList",
  ]
  description = "Labels set by the COUNT rules that want to be rate-limited. Not applicable for var.waf_scope = REGIONAL"
  # https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-ip-rep.html
  type = list(string)
}

variable "enable_count_ch_requests" {
  default     = false
  description = "Whether to enable a rule for counting the requests coming from Switzerland"
  type        = bool
}

variable "count_ch_priority" {
  default     = 40
  description = "The priority for counting requests coming from CH"
  type        = number
}

variable "count_ch_limit" {
  default     = 300
  description = "The limit for the 'emergency button' rule - not applied if set to 0"
  type        = number
}

variable "search_limitation" {
  default = {
    limit        = 0
    country_code = []
  }
  description = "The blocking limit for calls to /search for countries NOT in the country_code list - this value needs to be lower than the everybody else - not applied if the limit is set to 0"
  type = object({
    limit        = number
    country_code = set(string)
  })
}

variable "block_articles" {
  default     = []
  description = "The list of articles to block from some countries"
  type = list(object({
    name         = string
    priority     = number
    articles     = set(string)
    country_code = set(string)
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
  #     country_code = ["GB"]
  #     priority     = 10
  #   },
  #   ...
  # ]
}

variable "block_regex_pattern" {
  default     = {}
  description = "The list of regex to block from some countries"
  type = map(object({
    description  = string
    priority     = number
    country_code = set(string)
    regex_string = string
  }))
  # Example
  # {
  #   List_of_Article_to_Block_from_USA = {
  #     description  = "List of Article to Block from USA"
  #     priority     = 12
  #     country_code = ["US"]
  #     regex_string = "\\/content\\/(168154293778|199781524264|295880478843|456984065155|521246040231|548039927522|770770342355|850519746098|857984311223|875532264517|892009682269|961874634370)$"
  #   }
  # }
}

variable "allowed_partners" {
  default     = []
  description = "Allowed partner host headers"
  type = list(object({
    name     = string
    priority = number
    hostname = set(string)
  }))
  # Example
  # [
  #   { name     = "Allow_partner-xxxxx"
  #     priority = 5
  #     hostname = ["partner-xxxxx.yyyyy.domain.ch"]
  #   },
  #   ...
  # ]
}

# LOGS

variable "enable_logging" {
  description = "Enable waf logs."
  type        = bool
  default     = false
}

variable "deploy_athena_queries" {
  description = "Enables the deployment of the athena presaved queries to easily access the logs generated by waf"
  default     = true
  type        = bool
}

variable "logs_bucket_name" {
  description = "Override the default bucket name for waf logs. Default name: `aws-waf-logs-<lower(var.waf_scope)>-<data.aws_caller_identity.current.account_id>"
  default     = null
  type        = string
}
