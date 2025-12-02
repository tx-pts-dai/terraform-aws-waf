locals {
  google_whitelist_json = var.google_whitelist_config.enable ? jsondecode(data.http.googlebot[0].response_body) : "{}"
  google_bots_ipv6      = var.google_whitelist_config.enable ? compact([for p in local.google_whitelist_json.prefixes : try(p.ipv6Prefix, null)]) : []
  google_bots_ipv4      = var.google_whitelist_config.enable ? compact([for p in local.google_whitelist_json.prefixes : try(p.ipv4Prefix, null)]) : []
}


data "http" "googlebot" {
  count = var.google_whitelist_config.enable ? 1 : 0

  url = var.google_whitelist_config.url

  request_headers = merge(
    {
      Accept       = "application/json"
      "User-Agent" = "terraform-http"
    },
    var.google_whitelist_config.http_call_extra_headers
  )
}
