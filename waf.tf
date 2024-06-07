## Priorities:
# 0: limit_search_requests_by_countries
# 1-9: block_uri_path_string
# 10-19: block_articles
# 20-29: block_regex_pattern
# 30-39 free
# 40: whitelisted_ips_v4
# 41: whitelisted_ips_v6
# 42: Rate_limit_everything_apart_from_CH
# 43: count_requests_from_ch
# 44-49: free
# 50-59: AWS Managed rule groups (these are the ones that only count and label requests)
# 60: AWS managed rule labels rate limit
# 70-79: country_rates
# 80: everybody_else_limit


locals {
  everybody_else_exclude_country_codes = distinct(flatten([ # find all the country_codes mentioned in our rules
    for rules in var.country_rates : [rules.country_codes]
  ]))

  group_whitelist_ipv6 = compact(concat(
    var.whitelisted_ips_v6,
    local.google_bots_ipv6, # empty if enable_google_bots_whitelist is set to false
  ))
  group_whitelist_ipv4 = compact(concat(
    var.whitelisted_ips_v4,
    local.google_bots_ipv4,           # empty if enable_google_bots_whitelist is set to false
    local.oracle_data_cloud_crawlers, # empty if enable_oracle_crawler_whitelist is set to false
    local.parsely_crawlers,           # empty if enable_parsely_crawlers_whitelist is set to false
    local.k6_load_generators_ipv4,    # empty if enable_k6_whitelist is set to false
  ))
  rate_limit_response_key = "rate-limit-error"
}

resource "aws_wafv2_ip_set" "whitelisted_ips_v4" {
  count              = length(local.group_whitelist_ipv4) > 0 ? 1 : 0
  name               = "whitelisted_ips_v4"
  scope              = var.waf_scope
  ip_address_version = "IPV4"
  addresses          = local.group_whitelist_ipv4
}

resource "aws_wafv2_ip_set" "whitelisted_ips_v6" {
  count              = length(local.group_whitelist_ipv6) > 0 ? 1 : 0
  name               = "whitelisted_ips_v6"
  scope              = var.waf_scope
  ip_address_version = "IPV6"
  addresses          = local.group_whitelist_ipv6
}

resource "aws_wafv2_regex_pattern_set" "string" {
  for_each    = var.block_regex_pattern
  name        = each.key
  description = each.value.description
  scope       = var.waf_scope

  regular_expression {
    regex_string = each.value.regex_string
  }
}

resource "aws_wafv2_web_acl" "waf" {
  name  = var.waf_name
  scope = var.waf_scope
  default_action {
    allow {}
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.waf_name
    sampled_requests_enabled   = true
  }

  custom_response_body {
    key          = local.rate_limit_response_key
    content      = <<MULTILINE
      <h1>HTTP Error 429 - Too Many Requests</h1>
      <p>Your device sent us too many requests in the past 5 minutes. Please wait a few minutes before retrying.</p>
      <p>Info: Using VPNs, proxies or public wifi might affect negatively your experience. If you are using one, please try to disable it to see if the problem persists.</p>
      <br/>
      <p>If, instead, you believe you have been blocked by accident, please report with a screenshot and a quick summary of what you were trying to visit. This will greatly help us improving our protection systems.</p>
    MULTILINE
    content_type = "TEXT_HTML"
  }

  dynamic "rule" {
    for_each = length(local.group_whitelist_ipv4) == 0 ? [] : [1]
    content {
      name     = "whitelisted_ips_v4"
      priority = 40
      action {
        allow {}
      }
      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.whitelisted_ips_v4[0].arn
          dynamic "ip_set_forwarded_ip_config" {
            for_each = var.waf_scope == "REGIONAL" ? [1] : []
            content {
              header_name       = "X-Forwarded-For"
              fallback_behavior = "MATCH"
              position          = "ANY" # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl#position
            }
          }
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "whitelisted_ips_v4"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = length(local.group_whitelist_ipv6) == 0 ? [] : [1]
    content {
      name     = "whitelisted_ips_v6"
      priority = 41
      action {
        allow {}
      }
      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.whitelisted_ips_v6[0].arn
          dynamic "ip_set_forwarded_ip_config" {
            for_each = var.waf_scope == "REGIONAL" ? [1] : []
            content {
              header_name       = "X-Forwarded-For"
              fallback_behavior = "MATCH"
              position          = "ANY" # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl#position
            }
          }
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "whitelisted_ips_v6"
        sampled_requests_enabled   = true
      }
    }
  }

  # This rule is meant to be a failsafe switch in case of attack
  # Change "count" to "block" in the console if you are under attack and want to
  # rate limit to a low number of requests every country except Switzerland
  rule {
    name     = "rate_limit_everything_apart_from_CH"
    priority = 42
    action {
      count {}
    }
    statement {
      rate_based_statement {
        aggregate_key_type = "IP"
        limit              = 300
        scope_down_statement {
          not_statement {
            statement {
              geo_match_statement {
                country_codes = ["CH"]
                dynamic "forwarded_ip_config" {
                  for_each = var.waf_scope == "REGIONAL" ? [1] : []
                  content {
                    header_name       = "X-Forwarded-For"
                    fallback_behavior = "MATCH"
                  }
                }
              }
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate_limit_everything_apart_from_CH"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = var.count_requests_from_ch ? [1] : []
    content {
      name     = "Switzerland"
      priority = 43
      action {
        count {}
      }
      statement {
        geo_match_statement {
          country_codes = ["CH"]
          dynamic "forwarded_ip_config" {
            for_each = var.waf_scope == "REGIONAL" ? [1] : []
            content {
              header_name       = "X-Forwarded-For"
              fallback_behavior = "MATCH"
            }
          }
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "Switzerland"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.whitelisted_headers != null ? [1] : []
    content {
      name     = "Whitelist based on headers"
      priority = 45
      action {
        allow {}
      }
      statement {
        or_statement {
          dynamic "statement" {
            for_each = var.whitelisted_headers.headers
            content {
              byte_match_statement {
                positional_constraint = var.whitelisted_headers.string_match_type
                search_string         = each.value
                field_to_match {
                  single_header {
                    name = each.key
                  }
                }
                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "Whitelisted headers"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.aws_managed_rule_groups
    content {
      name     = rule.value.name
      priority = rule.value.priority
      override_action {
        count {} # valid blocks: count or none
      }
      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = "AWS"
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.country_rates
    content {
      name     = rule.value.name
      priority = rule.value.priority
      action {
        block {
          custom_response {
            custom_response_body_key = local.rate_limit_response_key
            response_code            = 429
          }
        }
      }
      statement {
        rate_based_statement {
          aggregate_key_type = "IP"
          limit              = rule.value.limit
          scope_down_statement {
            geo_match_statement {
              country_codes = rule.value.country_codes
              dynamic "forwarded_ip_config" {
                for_each = var.waf_scope == "REGIONAL" ? [1] : []
                content {
                  header_name       = "X-Forwarded-For"
                  fallback_behavior = "MATCH"
                }
              }
            }
          }
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.everybody_else_limit == 0 ? [] : [1]
    content {
      name     = "Everybody_else"
      priority = 80
      action {
        block {
          custom_response {
            custom_response_body_key = local.rate_limit_response_key
            response_code            = 429
          }
        }
      }
      statement {
        rate_based_statement {
          aggregate_key_type = "IP"
          limit              = var.everybody_else_limit

          scope_down_statement {
            not_statement {
              statement {
                geo_match_statement {
                  country_codes = local.everybody_else_exclude_country_codes
                  dynamic "forwarded_ip_config" {
                    for_each = var.waf_scope == "REGIONAL" ? [1] : []
                    content {
                      header_name       = "X-Forwarded-For"
                      fallback_behavior = "MATCH"
                    }
                  }
                }
              }
            }
          }
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "Everybody_else"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = length(var.limit_search_requests_by_countries.country_codes) > 0 ? [1] : []
    content {
      name     = "limit_search_requests_by_countries"
      priority = 0
      action {
        block {
          custom_response {
            custom_response_body_key = local.rate_limit_response_key
            response_code            = 429
          }
        }
      }
      statement {
        rate_based_statement {
          aggregate_key_type = "IP"
          limit              = var.limit_search_requests_by_countries.limit
          scope_down_statement {
            and_statement {
              statement {
                byte_match_statement {
                  positional_constraint = "STARTS_WITH"
                  search_string         = "/search"
                  field_to_match {
                    uri_path {}
                  }
                  text_transformation {
                    priority = 0
                    type     = "NONE"
                  }
                }
              }
              statement {
                not_statement {
                  statement {
                    geo_match_statement {
                      country_codes = var.limit_search_requests_by_countries.country_codes
                      dynamic "forwarded_ip_config" {
                        for_each = var.waf_scope == "REGIONAL" ? [1] : []
                        content {
                          header_name       = "X-Forwarded-For"
                          fallback_behavior = "MATCH"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "limit_search_requests_by_countries"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.block_uri_path_string
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        block {}
      }

      statement {
        byte_match_statement {
          positional_constraint = rule.value.positional_constraint
          search_string         = rule.value.search_string

          field_to_match {
            uri_path {}
          }

          text_transformation {
            priority = 0
            type     = "NONE"
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.block_articles
    content {
      name     = rule.value.name
      priority = rule.value.priority
      action {
        block {}
      }
      statement {
        and_statement {
          statement {
            geo_match_statement {
              country_codes = rule.value.country_codes
              dynamic "forwarded_ip_config" {
                for_each = var.waf_scope == "REGIONAL" ? [1] : []
                content {
                  header_name       = "X-Forwarded-For"
                  fallback_behavior = "MATCH"
                }
              }
            }
          }
          dynamic "statement" {
            # or_statement needs 2 arguments so handle the case when only one article is in the rule
            for_each = length(rule.value.articles) > 1 ? [1] : [] # if more than one element use or_statement
            content {
              or_statement {
                dynamic "statement" {
                  for_each = rule.value.articles
                  content {
                    byte_match_statement {
                      positional_constraint = "ENDS_WITH"
                      search_string         = statement.value
                      field_to_match {
                        uri_path {}
                      }
                      text_transformation {
                        priority = 0
                        type     = "NONE"
                      }
                    }
                  }
                }
              }
            }
          }
          dynamic "statement" {
            # or_statement needs 2 arguments so handle the case when only one article is in the rule
            for_each = length(rule.value.articles) == 1 ? rule.value.articles : [] # if just one element skip or_statement
            content {
              byte_match_statement {
                positional_constraint = "ENDS_WITH"
                search_string         = statement.value
                field_to_match {
                  uri_path {}
                }
                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.block_regex_pattern
    content {
      name     = rule.key
      priority = rule.value.priority

      action {
        block {}
      }

      statement {
        and_statement {
          statement {
            geo_match_statement {
              country_codes = rule.value.country_codes
              dynamic "forwarded_ip_config" {
                for_each = var.waf_scope == "REGIONAL" ? [1] : []
                content {
                  header_name       = "X-Forwarded-For"
                  fallback_behavior = "MATCH"
                }
              }
            }
          }
          statement {
            regex_pattern_set_reference_statement {
              arn = aws_wafv2_regex_pattern_set.string[rule.key].arn

              field_to_match {
                uri_path {}
              }

              text_transformation {
                priority = 1
                type     = "NONE"
              }
            }
          }
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }
  rule {
    name     = "aws_managed_rule_labels"
    priority = 60

    override_action {
      none {}
    }

    statement {
      rule_group_reference_statement {
        arn = aws_wafv2_rule_group.aws_managed_rule_labels.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws_managed_rule_labels"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_wafv2_rule_group" "aws_managed_rule_labels" {
  name     = "aws_managed_rule_labels"
  scope    = var.waf_scope
  capacity = 50

  custom_response_body {
    key          = local.rate_limit_response_key
    content      = <<MULTILINE
      <h1>HTTP Error 429 - Too Many Requests</h1>
      <p>Your device sent us too many requests in the past 5 minutes. Please wait a few minutes before retrying.</p>
      <p>Info: Using VPNs, proxies or public wifi might affect negatively your experience. If you are using one, please try to disable it to see if the problem persists.</p>
      <br/>
      <p>If, instead, you believe you have been blocked by accident, please report with a screenshot and a quick summary of what you were trying to visit. This will greatly help us improving our protection systems.</p>
    MULTILINE
    content_type = "TEXT_HTML"
  }

  dynamic "rule" {
    for_each = var.aws_managed_rule_labels
    content {
      name     = rule.value.name
      priority = rule.value.priority
      action {
        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {
            custom_response {
              custom_response_body_key = local.rate_limit_response_key
              response_code            = 429
            }
          }
        }
        dynamic "captcha" {
          for_each = rule.value.action == "captcha" ? [1] : []
          content {}
        }
        dynamic "challenge" {
          for_each = rule.value.action == "challenge" ? [1] : []
          content {}
        }
      }
      dynamic "captcha_config" {
        for_each = rule.value.action == "captcha" ? [1] : []
        content {
          immunity_time_property {
            immunity_time = rule.value.immunity_seconds
          }
        }
      }
      # dynamic "challenge_config" { 
      # # available in the console but seems to be not supported on tf (?) 
      # # even if is mentioned in the docs https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl#challenge_config-block
      # # and is in an open issue https://github.com/hashicorp/terraform-provider-aws/issues/29071 
      #   for_each = rule.value.action == "challenge" ? [1] : []
      #   content {
      #     immunity_time_property {
      #       immunity_time = rule.value.immunity_seconds
      #     }
      #   }
      # }
      statement {
        dynamic "or_statement" {
          # or_statement needs 2 arguments so handle the case when only one label is in the rule
          for_each = length(rule.value.labels) > 1 && !rule.value.enable_rate_limiting ? [1] : []
          # if rate limiting is not enabled and more than one element use or_statement
          content {
            dynamic "statement" {
              for_each = rule.value.labels
              content {
                label_match_statement {
                  key   = statement.value
                  scope = "LABEL"
                }
              }
            }
          }
        }
        dynamic "label_match_statement" {
          # or_statement needs 2 arguments so handle the case when only one label is in the rule
          for_each = length(rule.value.labels) == 1 && !rule.value.enable_rate_limiting ? rule.value.labels : []
          # if rate limiting is not enabled and one element skip or_statement
          content {
            key   = label_match_statement.value
            scope = "LABEL"
          }
        }
        dynamic "rate_based_statement" {
          for_each = rule.value.enable_rate_limiting ? [1] : [] # create rate_based_statement only if rate limiting is enabled
          content {
            aggregate_key_type = "IP"
            limit              = rule.value.limit
            dynamic "scope_down_statement" {
              # or_statement needs 2 arguments so handle the case when only one label is in the rule
              for_each = length(rule.value.labels) > 1 ? [1] : [] # if more than one element use or_statement
              content {
                or_statement {
                  dynamic "statement" {
                    for_each = rule.value.labels
                    content {
                      label_match_statement {
                        scope = "LABEL"
                        key   = statement.value
                      }
                    }
                  }
                }
              }
            }
            dynamic "scope_down_statement" {
              # or_statement needs 2 arguments so handle the case when only one label is in the rule
              for_each = length(rule.value.labels) == 1 ? rule.value.labels : [] # if one element skip or_statement
              content {
                label_match_statement {
                  scope = "LABEL"
                  key   = scope_down_statement.value
                }
              }
            }
          }
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "aws_managed_rule_labels"
    sampled_requests_enabled   = true
  }
}
