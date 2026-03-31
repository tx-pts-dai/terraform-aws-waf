terraform {
  required_version = ">= 1.3.0"
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = ">= 3.0"
    }
  }
}

data "http" "ip_list" {
  url = var.url

  request_headers = merge(
    {
      Accept     = "application/json"
      User-Agent = "terraform-http"
    },
    var.request_headers
  )
}

locals {
  parsed_json = jsondecode(data.http.ip_list.response_body)

  # Resolve the array of entries from the JSON root.
  # try() is used instead of a ternary because the ternary operator enforces static type
  # consistency between both branches. When root_key is set the result is a tuple (the nested
  # array), but when root_key is empty the JSON root itself is the array — jsondecode gives
  # these different types and the ternary would fail type-checking even when the condition is true.
  entries_raw = try(local.parsed_json[var.root_key], local.parsed_json)

  # Apply optional key/value filter on object entries
  entries = var.filter != null ? [
    for e in local.entries_raw : e
    if try(tostring(lookup(e, var.filter.key, null)), null) == var.filter.value
  ] : local.entries_raw

  # IPv4: flat array of plain IPs, or key-lookup within object entries
  ipv4_addresses = var.flat_array ? compact([
    for e in local.entries_raw : (
      var.flat_cidr_prefix != null ? "${e}/${var.flat_cidr_prefix}" : tostring(e)
    )
    ]) : (
    var.ipv4_key != "" ? compact([
      for e in local.entries : try(tostring(lookup(e, var.ipv4_key, null)), null)
    ]) : []
  )

  # IPv6: key-lookup within object entries (not applicable for flat arrays)
  ipv6_addresses = !var.flat_array && var.ipv6_key != "" ? compact([
    for e in local.entries : try(tostring(lookup(e, var.ipv6_key, null)), null)
  ]) : []
}
