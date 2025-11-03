locals {
  k6_whitelist_json = jsondecode(data.http.k6_load_generators.response_body)
  k6_load_generators_ipv4 = var.k6_whitelist_config.enable ? compact([
    for entry in local.k6_whitelist_json.prefixes : entry.ip_prefix if entry.region == "eu-central-1"
  ]) : []
}


data "http" "k6_load_generators" {
  url = var.k6_whitelist_config.url

  request_headers = {
    Accept = "application/json"
  }
}
