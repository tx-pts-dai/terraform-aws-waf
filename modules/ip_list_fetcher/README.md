# ip_list_fetcher

A generic sub-module that fetches an IP list from a remote HTTP endpoint, parses the response into IPv4 and IPv6 CIDR lists, and supports custom request headers (e.g. authentication tokens). It handles multiple JSON structures out of the box — nested objects, flat arrays, and filtered subsets — so it works with a wide range of upstream IP list providers. Use it to supply dynamic IP whitelists to the parent WAF module via `var.ip_whitelisting` — without coupling the WAF module to any particular upstream URL or JSON schema.

## Why this sub-module exists

Previously, Googlebot, Parse.ly, and k6 IP lists were fetched directly inside the root WAF module. This meant:

- URL changes at the upstream provider caused Terraform drift in the module.
- Adding new IP sources (e.g. A-team crawlers) required modifying the module, tagging a new release, and bumping the version everywhere.

With this sub-module the caller owns the fetch logic. The WAF module only receives a plain `ip_whitelisting` map.

## Supported JSON formats

| Format | Example source | Config |
|--------|---------------|--------|
| Prefixes object with per-family keys | Google crawlers | `root_key = "prefixes"`, `ipv4_key = "ipv4Prefix"`, `ipv6_key = "ipv6Prefix"` |
| Prefixes object with single IP key + filter | k6 / AWS IP ranges | `root_key = "prefixes"`, `ipv4_key = "ip_prefix"`, `filter = { key = "region", value = "eu-central-1" }` |
| Flat array of plain IPs | Parse.ly crawlers | `flat_array = true`, `flat_cidr_prefix = 32` |

## Usage examples

### Googlebot

```hcl
module "googlebot_ips" {
  source = "./modules/ip_list_fetcher"

  url      = "https://developers.google.com/static/crawling/ipranges/common-crawlers.json"
  root_key = "prefixes"
  ipv4_key = "ipv4Prefix"
  ipv6_key = "ipv6Prefix"
}

module "waf" {
  source = "./"

  ip_whitelisting = {
    googlebot_ipv4 = {
      ips                = module.googlebot_ips.ipv4_addresses
      ip_address_version = "IPV4"
      priority           = 1
      insert_header      = { "x-bot" = "googlebot" }
    }
    googlebot_ipv6 = {
      ips                = module.googlebot_ips.ipv6_addresses
      ip_address_version = "IPV6"
      priority           = 2
      insert_header      = { "x-bot" = "googlebot" }
    }
  }
}
```

### Parse.ly crawlers

```hcl
module "parsely_ips" {
  source = "./modules/ip_list_fetcher"

  url              = "https://www.parse.ly/static/data/crawler-ips.json"
  flat_array       = true
  flat_cidr_prefix = 32
}

module "waf" {
  source = "./"

  ip_whitelisting = {
    parsely_ipv4 = {
      ips                = module.parsely_ips.ipv4_addresses
      ip_address_version = "IPV4"
      priority           = 3
    }
  }
}
```

### k6 load generators (eu-central-1)

```hcl
module "k6_ips" {
  source = "./modules/ip_list_fetcher"

  url      = "https://ip-ranges.amazonaws.com/ip-ranges.json"
  root_key = "prefixes"
  ipv4_key = "ip_prefix"
  filter   = { key = "region", value = "eu-central-1" }
}

module "waf" {
  source = "./"

  ip_whitelisting = {
    k6_ipv4 = {
      ips                = module.k6_ips.ipv4_addresses
      ip_address_version = "IPV4"
      priority           = 4
    }
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `url` | URL to fetch the IP list JSON from | `string` | — | yes |
| `request_headers` | Additional HTTP request headers | `map(string)` | `{}` | no |
| `root_key` | Key at the JSON root containing the entries array. Empty = root is the array | `string` | `""` | no |
| `ipv4_key` | Key within each entry for IPv4 CIDR | `string` | `""` | no |
| `ipv6_key` | Key within each entry for IPv6 CIDR | `string` | `""` | no |
| `flat_array` | Set true when the array contains plain IP strings, not objects | `bool` | `false` | no |
| `flat_cidr_prefix` | CIDR prefix length to append to flat IPs (e.g. `32` → `/32`) | `number` | `null` | no |
| `filter` | Optional `{ key, value }` filter applied to entries before IP extraction | `object` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| `ipv4_addresses` | List of IPv4 CIDR ranges |
| `ipv6_addresses` | List of IPv6 CIDR ranges |
