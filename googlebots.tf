locals {
  google_whitelist_json = jsondecode(data.http.googlebot.response_body)
  google_bots_ipv6      = var.google_whitelist_config.enable ? compact([for p in local.google_whitelist_json.prefixes : try(p.ipv6Prefix, null)]) : []
  google_bots_ipv4      = var.google_whitelist_config.enable ? compact([for p in local.google_whitelist_json.prefixes : try(p.ipv4Prefix, null)]) : []
}


data "http" "googlebot" {
  url = var.google_whitelist_config.url

  request_headers = {
    Accept = "application/json"
  }
}
