locals {
  google_whitelist_json = jsondecode(data.http.googlebot.response_body)
  google_bots_ipv6      = var.google_bot_whitelisting.whitelist ? compact([for p in local.google_whitelist_json.prefixes : try(p.ipv6Prefix, null)]) : []
  google_bots_ipv4      = var.google_bot_whitelisting.whitelist ? compact([for p in local.google_whitelist_json.prefixes : try(p.ipv4Prefix, null)]) : []
}


data "http" "googlebot" {
  url = var.google_bot_whitelisting.url

  request_headers = {
    Accept = "application/json"
  }
}
