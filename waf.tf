
locals {
  parsed_allowed_ipv4 = [
    for ip in var.allowed_ips :
    format(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}/\\d{1,2}", ip))
    if ip != ""
  ]
  # Not the "real" regexp for ipv6. The right one has around 1000 characters...
  parsed_allowed_ipv6 = [
    for ip in var.allowed_ips_v6 :
    format(regex("^[0-9a-fA-F:]*/\\d{1,2}", ip))
    if ip != ""
  ]
  self_ips = [
    for ip in var.self_ips :
    format("%s/32", ip)
  ]
  everybody_else_exlude_countries = distinct(flatten([
    for rules in var.country_rates : [rules.country_code]
  ]))

  final_allowed_ipv6 = compact(concat(
    local.parsed_allowed_ipv6,
    local.google_bots_ipv6, # empty if enable_google_bots_whitelist is set to false
  ))
  final_allowed_ipv4 = compact(concat(
    var.whitelisted_ip_ranges,
    local.parsed_allowed_ipv4,
    local.google_bots_ipv4,           # empty if enable_google_bots_whitelist is set to false
    local.oracle_data_cloud_crawlers, # empty if enable_oracle_crawler_whitelist is set to false
    local.parsely_crawlers,           # empty if enable_parsely_crawlers_whitelist is set to false
    local.k6_load_generators_ipv4,    # empty if enable_k6_whitelist is set to false
  ))
  rate_limit_response_key = "rate-limit-error"
}

resource "aws_wafv2_ip_set" "self" {
  count              = length(local.self_ips) > 0 ? 1 : 0
  name               = "self"
  scope              = var.waf_scope
  ip_address_version = "IPV4"
  addresses          = local.self_ips
}

resource "aws_wafv2_ip_set" "allowed_ips" {
  count              = length(local.final_allowed_ipv4) > 0 ? 1 : 0
  name               = "allowed_ips"
  scope              = var.waf_scope
  ip_address_version = "IPV4"
  addresses          = local.final_allowed_ipv4
}

resource "aws_wafv2_ip_set" "allowed_ips_v6" {
  count              = length(local.final_allowed_ipv6) > 0 ? 1 : 0
  name               = "allowed_ips_v6"
  scope              = var.waf_scope
  ip_address_version = "IPV6"
  addresses          = local.final_allowed_ipv6
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
    for_each = length(local.self_ips) == 0 ? [] : [1]
    content {
      name     = "self"
      priority = 0
      action {
        allow {}
      }
      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.self[0].arn
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
        metric_name                = "self"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = length(local.final_allowed_ipv4) == 0 ? [] : [1]
    content {
      name     = "allowed_ips"
      priority = 1
      action {
        allow {}
      }
      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.allowed_ips[0].arn
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
        metric_name                = "allowed_ips"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = length(local.final_allowed_ipv6) == 0 ? [] : [1]
    content {
      name     = "allowed_ips_v6"
      priority = 2
      action {
        allow {}
      }
      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.allowed_ips_v6[0].arn
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
        metric_name                = "allowed_ips_v6"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.allowed_partners
    content {
      name     = rule.value.name
      priority = rule.value.priority
      action {
        allow {}
      }
      dynamic "statement" {
        for_each = rule.value.hostname
        content {
          byte_match_statement {
            positional_constraint = "EXACTLY"
            search_string         = statement.value
            field_to_match {
              single_header {
                name = "host"
              }
            }
            text_transformation {
              priority = 0
              type     = "NONE"
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
    for_each = var.search_limitation.limit == 0 ? [] : [1]
    content {
      name     = "Limit_search"
      priority = 3
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
          limit              = var.search_limitation.limit
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
                      country_codes = var.search_limitation.country_code
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
        metric_name                = "Limit_search"
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
              country_codes = rule.value.country_code
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
      priority = 30
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
                  country_codes = local.everybody_else_exlude_countries
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
              country_codes = rule.value.country_code
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
              country_codes = rule.value.country_code
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

  # This rule is meant to be a failsafe switch in case of attack
  # Change "count" to "block" if you are under attack and want to
  # rate limit to a low number of requests every country apart from Switzerland
  rule {
    name     = "Rate_limit_everything_apart_from_CH"
    priority = 9000
    action {
      count {}
    }
    statement {
      rate_based_statement {
        aggregate_key_type = "IP"
        limit              = var.count_ch_limit
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
      metric_name                = "Rate_limit_everything_apart_from_CH"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = var.enable_count_ch_requests ? [1] : []
    content {
      name     = "Switzerland"
      priority = var.count_ch_priority
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
    for_each = var.aws_managed_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority
      override_action {
        count {}
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
    # Dont create this rule independently of var.aws_managed_rules_labels if length(var.aws_managed_rules) == 0
    # The rule created by var.aws_managed_rules is the one adding labels to the requests, therefore without the 
    # rule for var.aws_managed_rules this rule would have no labels to check and therefore should not be created
    for_each = length(var.aws_managed_rules_labels) > 0 && length(var.aws_managed_rules) > 0 ? [1] : []
    content {
      name     = "Rate_limit_based_on_AWS_labels"
      priority = 200
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
          limit              = var.aws_managed_rules_limit
          dynamic "scope_down_statement" {
            # or_statement needs 2 arguments so handle the case when only one article is in the rule
            for_each = length(var.aws_managed_rules_labels) > 1 ? [1] : [] # if more than one element use or_statement
            content {
              or_statement {
                dynamic "statement" {
                  for_each = var.aws_managed_rules_labels
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
            # or_statement needs 2 arguments so handle the case when only one article is in the rule
            for_each = length(var.aws_managed_rules_labels) == 1 ? var.aws_managed_rules_labels : [] # if one element skip or_statement
            content {
              label_match_statement {
                scope = "LABEL"
                key   = scope_down_statement.value
              }
            }
          }
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "Rate_limit_based_on_AWS_labels"
        sampled_requests_enabled   = true
      }
    }
  }
}
