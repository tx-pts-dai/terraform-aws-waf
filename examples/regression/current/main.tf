terraform {
  required_version = ">= 1.4.0"

  backend "s3" {
    bucket               = "tf-state-911453050078"
    key                  = "waf/examples/regression.tfstate"
    workspace_key_prefix = "terraform-aws-waf"
    dynamodb_table       = "terraform-lock"
    region               = "eu-central-1"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  alias  = "us"
}

module "waf" {
  source  = "tx-pts-dai/waf/aws"
  version = "~> 5.0"
  providers = {
    aws = aws.us
  }

  waf_name                          = "waf-module-regression-example"
  waf_scope                         = "CLOUDFRONT"
  waf_logs_retention                = 7
  enable_google_bots_whitelist      = true
  google_bots_url                   = "https://developers.google.com/search/apis/ipranges/googlebot.json"
  enable_parsely_crawlers_whitelist = false
  parsely_crawlers_url              = "https://www.parse.ly/static/data/crawler-ips.json"
  enable_k6_whitelist               = false
  k6_ip_ranges_url                  = "https://ip-ranges.amazonaws.com/ip-ranges.json"
  whitelisted_ips_v4                = []
  whitelisted_ips_v6                = []
  whitelisted_headers = {
    headers = {
      "MyCustomHeader"  = "Lighthouse"
      "MyCustomHeader2" = "Playwright-secretStr1ng-disco"
    }
  }
  aws_managed_rule_groups = [
    {
      name     = "AWSManagedRulesAnonymousIpList"
      priority = 50
    },
    {
      name     = "AWSManagedRulesAmazonIpReputationList"
      priority = 59
    }
  ]
  aws_managed_rule_labels = [
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
  country_count_rules = [
    {
      name          = "count-CH"
      limit         = 4000
      country_codes = ["CH"]
      priority      = 90
    },
    {
      name          = "count-DE"
      limit         = 1000
      country_codes = ["DE"]
      priority      = 91
    }
  ]
  count_requests_from_ch = false
  country_rates = [
    {
      name          = "Group_1-CH"
      limit         = 50000
      country_codes = ["CH"]
      action        = "captcha"
      priority      = 70
    },
    {
      name          = "Group_2-DE_AT_FR"
      limit         = 4000
      country_codes = ["AT", "FR", "DE"]
      priority      = 71
    },
    {
      name          = "Very_slow"
      limit         = 100
      country_codes = ["AR", "BD", "BR", "KH", "CN", "CO", "EC", "IN", "ID", "MX", "NP", "PK", "RU", "SG", "TR", "UA", "AE", "ZM", "VN"]
      priority      = 72
    }
  ]
  limit_search_requests_by_countries = {
    limit         = 100
    country_codes = ["CH"]
  }
  everybody_else_limit      = 0
  block_uri_path_string     = []
  block_articles            = []
  block_regex_pattern       = {}
  logs_bucket_name_override = null
}

module "waf_parallel" {
  source  = "tx-pts-dai/waf/aws"
  version = "~> 5.0"
  providers = {
    aws = aws.us
  }

  waf_name                          = "waf-module-regression-example-parallel"
  waf_scope                         = "CLOUDFRONT"
  waf_logs_retention                = 7
  enable_google_bots_whitelist      = true
  google_bots_url                   = "https://developers.google.com/search/apis/ipranges/googlebot.json"
  enable_parsely_crawlers_whitelist = false
  parsely_crawlers_url              = "https://www.parse.ly/static/data/crawler-ips.json"
  enable_k6_whitelist               = false
  k6_ip_ranges_url                  = "https://ip-ranges.amazonaws.com/ip-ranges.json"
  whitelisted_ips_v4                = []
  whitelisted_ips_v6                = []
  whitelisted_headers = {
    headers = {
      "MyCustomHeader"  = "Lighthouse"
      "MyCustomHeader2" = "Playwright-secretStr1ng-disco"
    }
  }
  aws_managed_rule_groups = [
    {
      name     = "AWSManagedRulesAnonymousIpList"
      priority = 50
    },
    {
      name     = "AWSManagedRulesAmazonIpReputationList"
      priority = 59
    }
  ]
  aws_managed_rule_labels = [
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
  count_requests_from_ch = false
  country_rates = [
    {
      name          = "Group_1-CH"
      limit         = 50000
      country_codes = ["CH"]
      action        = "captcha"
      priority      = 70
    },
    {
      name          = "Group_2-DE_AT_FR"
      limit         = 4000
      country_codes = ["AT", "FR", "DE"]
      priority      = 71
    },
    {
      name          = "Very_slow"
      limit         = 100
      country_codes = ["AR", "BD", "BR", "KH", "CN", "CO", "EC", "IN", "ID", "MX", "NP", "PK", "RU", "SG", "TR", "UA", "AE", "ZM", "VN"]
      priority      = 72
    }
  ]
  country_count_rules = [
    {
      name          = "count-CH"
      limit         = 4000
      country_codes = ["CH"]
      priority      = 90
    },
    {
      name          = "count-DE"
      limit         = 1000
      country_codes = ["DE"]
      priority      = 91
    }
  ]
  everybody_else_limit = 0
  limit_search_requests_by_countries = {
    limit         = 100
    country_codes = ["CH"]
  }
  block_uri_path_string     = []
  block_articles            = []
  block_regex_pattern       = {}
  logs_bucket_name_override = null
  enable_logging            = true

  deploy_logs                  = false
  alternative_logs_bucket_name = module.waf.logs_bucket_name
}
