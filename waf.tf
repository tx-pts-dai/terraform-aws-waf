locals {
  everybody_else_exclude_country_codes = distinct(flatten([ # find all the country_codes mentioned in our rules
    for rules in var.country_rates : [rules.country_codes]
  ]))
  country_rate_chunks = chunklist(var.country_rates, 4)
  country_rate_chunks_map = zipmap(
    range(length(local.country_rate_chunks)),
    local.country_rate_chunks
  )


  rate_limit_response_key = "rate-limit-error"
  custom_response_body    = <<MULTILINE
      <div style="font-family: Arial, sans-serif;text-align: center; padding: 50px; background-color: #f4f4f4;">
        <div style="background-color: #fff; padding: 20px; border-radius: 10px; box-shadow: 0 0 10px rgba(0, 0, 0, 0.1); display: inline-block; max-width: 600px; margin: auto;">
          <img src="${var.logo_path}" alt="Company Logo" style="width: 150px; margin-bottom: 20px;">
          <h1 style="color: #e74c3c;">HTTP Error 429 - Too many requests</h1>
          <p style="color: #555;">Your device sent us too many requests in the past 5 minutes. Please wait a few minutes before retrying.</p>
          <p style="color: #888; font-size: 0.9em;">Info: Using VPNs, proxies or public wifi might affect negatively your experience. If you are using one, please try to disable it to see if the problem persists.</p>
          <br/>
          <p style="color: #333; margin-top: 20px;">If, instead, you believe you have been blocked by accident, please report with a screenshot and a quick summary of what you were trying to visit. This will greatly help us improving our protection systems.</p>
        </div>
      </div>
  MULTILINE

}

resource "aws_wafv2_regex_pattern_set" "string" {
  for_each    = var.block_regex_pattern
  name        = "${var.waf_name}_${each.key}"
  description = each.value.description
  scope       = var.waf_scope

  regular_expression {
    regex_string = each.value.regex_string
  }
  lifecycle {
    create_before_destroy = true
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
    content      = local.custom_response_body
    content_type = "TEXT_HTML"
  }

  dynamic "rule" {
    for_each = var.blocked_headers != null ? [1] : []
    content {
      name     = "${var.waf_name}_block_based_on_headers"
      priority = var.blocked_headers.priority
      action {
        block {}
      }
      dynamic "statement" {
        # multiple statements - or_statement handles the case of more than 2 headers in the rule
        for_each = length(var.blocked_headers.rules) > 1 ? [1] : []
        content {
          or_statement {
            dynamic "statement" {
              for_each = var.blocked_headers.rules
              content {
                byte_match_statement {
                  positional_constraint = statement.value.string_match_type
                  search_string         = statement.value.value
                  field_to_match {
                    single_header {
                      name = lower(statement.value.header)
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
      }
      dynamic "statement" {
        # single statement - only one header is in the rule
        for_each = length(var.blocked_headers.rules) == 1 ? var.blocked_headers.rules : []
        content {
          byte_match_statement {
            positional_constraint = statement.value.string_match_type
            search_string         = statement.value.value
            field_to_match {
              single_header {
                name = lower(statement.value.header)
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
        metric_name                = "${var.waf_name}_block_based_on_headers"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = length(var.ip_whitelisting) == 0 ? [] : [1]
    content {
      name     = "${var.waf_name}_whitelist_group"
      priority = var.whitelist_group_priority
      override_action {
        none {}
      }
      statement {
        rule_group_reference_statement {
          arn = aws_wafv2_rule_group.whitelist.arn
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.waf_name}_whitelist_group"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = length(var.limit_search_requests_by_countries.country_codes) > 0 ? [1] : []
    content {
      name     = "${var.waf_name}_limit_search_requests_by_countries"
      priority = var.limit_search_requests_by_countries.priority
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
        metric_name                = "${var.waf_name}_limit_search_requests_by_countries"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.block_uri_path_string
    content {
      name     = "${var.waf_name}_${rule.value.name}"
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
        metric_name                = "${var.waf_name}_${rule.value.name}"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.block_articles
    content {
      name     = "${var.waf_name}_${rule.value.name}"
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
            # multiple articles - or_statement handles the case of more than one article in the rule
            for_each = length(rule.value.articles) > 1 ? [1] : []
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
            # single article - only one article is in the rule
            for_each = length(rule.value.articles) == 1 ? rule.value.articles : []
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
        metric_name                = "${var.waf_name}_${rule.value.name}"
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

  # This rule is meant to be a failsafe switch in case of attack
  # Change "count" to "block" in the console if you are under attack and want to
  # rate limit to a low number of requests every country except Switzerland
  rule {
    name     = "${var.waf_name}_rate_limit_everything_apart_from_CH"
    priority = var.rate_limit_failsafe_priority
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
      metric_name                = "${var.waf_name}_rate_limit_everything_apart_from_CH"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = var.count_requests_from_ch.enabled ? [1] : []
    content {
      name     = "${var.waf_name}_Switzerland"
      priority = var.count_requests_from_ch.priority
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
        metric_name                = "${var.waf_name}_Switzerland"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.whitelisted_headers != null ? [1] : []
    content {
      name     = "${var.waf_name}_Whitelist_based_on_headers"
      priority = var.whitelisted_headers.priority
      action {
        allow {}
      }
      dynamic "statement" {
        # multiple headers - or_statement handles the case of more than one header in the rule
        for_each = length(var.whitelisted_headers.headers) > 1 ? [1] : []
        content {
          or_statement {
            dynamic "statement" {
              for_each = var.whitelisted_headers.headers
              content {
                byte_match_statement {
                  positional_constraint = var.whitelisted_headers.string_match_type
                  search_string         = statement.value
                  field_to_match {
                    single_header {
                      name = lower(statement.key)
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
      }
      dynamic "statement" {
        # single header - only one header is in the rule
        for_each = length(var.whitelisted_headers.headers) == 1 ? var.whitelisted_headers.headers : {}
        content {
          byte_match_statement {
            positional_constraint = var.whitelisted_headers.string_match_type
            search_string         = statement.value
            field_to_match {
              single_header {
                name = lower(statement.key)
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
        metric_name                = "${var.waf_name}_Whitelisted_headers"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.aws_managed_rule_groups
    content {
      name     = "${var.waf_name}_${rule.value.name}"
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
        metric_name                = "${var.waf_name}_${rule.value.name}"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.everybody_else_config.limit == 0 ? [] : [1]
    content {
      name     = "${var.waf_name}_Everybody_else"
      priority = var.everybody_else_config.priority
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
          limit              = var.everybody_else_config.limit

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
        metric_name                = "${var.waf_name}_Everybody_else"
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "${var.waf_name}_aws_managed_rule_labels"
    priority = var.aws_managed_rule_labels_priority

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
      metric_name                = "${var.waf_name}_aws_managed_rule_labels"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = aws_wafv2_rule_group.country_rate_rules
    content {
      name     = "${var.waf_name}_country_rate_rules_${rule.key}"
      priority = 70 + tonumber(rule.key)
      override_action {
        none {}
      }
      statement {
        rule_group_reference_statement {
          arn = rule.value.arn
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.waf_name}_country_rate_rules_${rule.key}"
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = length(var.country_count_rules) > 0 ? [1] : []
    content {
      name     = "${var.waf_name}_country_count_rules"
      priority = var.country_count_rules_priority
      override_action {
        none {}
      }
      statement {
        rule_group_reference_statement {
          arn = aws_wafv2_rule_group.country_count_rules[0].arn
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.waf_name}_country_count_rules"
        sampled_requests_enabled   = true
      }
    }
  }

}

resource "aws_wafv2_rule_group" "country_rate_rules" {
  for_each = local.country_rate_chunks_map
  name     = "${var.waf_name}_country_rate_rules_${each.key}"
  scope    = var.waf_scope
  capacity = 50
  custom_response_body {
    key          = local.rate_limit_response_key
    content      = local.custom_response_body
    content_type = "TEXT_HTML"
  }
  dynamic "rule" {
    for_each = each.value
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
        metric_name                = "${var.waf_name}_${rule.value.name}"
        sampled_requests_enabled   = true
      }
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.waf_name}_country_rate_rules"
    sampled_requests_enabled   = true
  }
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_wafv2_rule_group" "aws_managed_rule_labels" {
  name     = "${var.waf_name}_aws_managed_rule_labels"
  scope    = var.waf_scope
  capacity = 50

  custom_response_body {
    key          = local.rate_limit_response_key
    content      = local.custom_response_body
    content_type = "TEXT_HTML"
  }

  dynamic "rule" {
    for_each = var.aws_managed_rule_labels
    content {
      name     = "${var.waf_name}_${rule.value.name}"
      priority = rule.value.priority
      action {
        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }
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
          # multiple labels - or_statement handles the case of more than one label in the rule (only when rate limiting is disabled)
          for_each = length(rule.value.labels) > 1 && !rule.value.enable_rate_limiting ? [1] : []
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
          # single label - only one label in the rule (only when rate limiting is disabled)
          for_each = length(rule.value.labels) == 1 && !rule.value.enable_rate_limiting ? rule.value.labels : []
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
              # multiple labels - or_statement handles the case of more than one label in the rule
              for_each = length(rule.value.labels) > 1 ? [1] : []
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
              # single label - only one label in the rule
              for_each = length(rule.value.labels) == 1 ? rule.value.labels : []
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
        metric_name                = "${var.waf_name}_${rule.value.name}"
        sampled_requests_enabled   = true
      }
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.waf_name}_aws_managed_rule_labels"
    sampled_requests_enabled   = true
  }
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_wafv2_rule_group" "country_count_rules" {
  count    = length(var.country_count_rules) > 0 ? 1 : 0
  name     = "${var.waf_name}_country_count_rules"
  scope    = var.waf_scope
  capacity = 100
  dynamic "rule" {
    for_each = var.country_count_rules
    content {
      name     = "${var.waf_name}_${rule.value.name}"
      priority = rule.value.priority
      action {
        count {}
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
        metric_name                = "${var.waf_name}_${rule.value.name}"
        sampled_requests_enabled   = true
      }
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.waf_name}_country_count_rules"
    sampled_requests_enabled   = true
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_wafv2_ip_set" "whitelist" {
  for_each           = var.ip_whitelisting
  name               = "${var.waf_name}_whitelist_${each.key}"
  scope              = var.waf_scope
  ip_address_version = each.value.ip_address_version
  addresses          = each.value.ips
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_wafv2_rule_group" "whitelist" {
  name     = "${var.waf_name}_whitelist"
  scope    = var.waf_scope
  capacity = 100
  dynamic "rule" {
    for_each = var.ip_whitelisting
    content {
      name     = "${var.waf_name}_${rule.key}"
      priority = rule.value.priority
      action {
        allow {
          dynamic "custom_request_handling" {
            for_each = rule.value.insert_header != null ? [1] : []
            content {
              dynamic "insert_header" {
                for_each = rule.value.insert_header
                content {
                  name  = insert_header.key
                  value = insert_header.value
                }
              }
            }

          }
        }
      }
      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.whitelist[rule.key].arn
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
        metric_name                = "${var.waf_name}_${rule.key}"
        sampled_requests_enabled   = true
      }
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.waf_name}_whitelist_add_header"
    sampled_requests_enabled   = true
  }
  lifecycle {
    create_before_destroy = true
  }
}
