locals {
  k6_whitelist_json = var.k6_whitelist_config.enable ? jsondecode(data.http.k6_load_generators[0].response_body) : null
  k6_load_generators_ipv4 = var.k6_whitelist_config.enable ? compact([
    for entry in local.k6_whitelist_json.prefixes : entry.ip_prefix if entry.region == "eu-central-1"
  ]) : []
}


data "http" "k6_load_generators" {
  count = var.k6_whitelist_config.enable ? 1 : 0

  url = var.k6_whitelist_config.url

  request_headers = merge(
    {
      Accept       = "application/json"
      "User-Agent" = "terraform-http"
    },
    var.k6_whitelist_config.http_call_extra_headers
  )
}
