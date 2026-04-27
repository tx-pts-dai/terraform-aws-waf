# Changelog

## [8.0.0]

This version introduces breaking changes to several variables to allow configurable WAF ACL priorities, removes built-in bot IP fetching in favour of the `ip_list_fetcher` submodule. **All users must update their Terraform configurations** when upgrading to this version.

### Breaking changes

#### `everybody_else_limit` renamed to `everybody_else_config` — type changed

The variable has been renamed and its type changed from a plain `number` to an object, allowing the WAF ACL priority to be configured independently of the rate limit.

```hcl
# Before
everybody_else_limit = 400

# After
everybody_else_config = { limit = 400 }
# Optionally set priority (default 80):
everybody_else_config = { limit = 400, priority = 80 }
```

#### `blocked_headers` type changed

The variable type changed from a flat `list(object)` to an `object` with a `rules` field, allowing the WAF ACL priority to be set independently.

```hcl
# Before
blocked_headers = [
  { header = "host", value = "example.cloudfront.net" }
]

# After
blocked_headers = {
  rules = [
    { header = "host", value = "example.cloudfront.net" }
  ]
  # Optionally set priority (default 0):
  # priority = 0
}
```

#### `count_requests_from_ch` type changed

The variable type changed from `bool` to an object, allowing the WAF ACL priority to be configured.

```hcl
# Before
count_requests_from_ch = false

# After
count_requests_from_ch = { enabled = false }
# Optionally set priority (default 43):
count_requests_from_ch = { enabled = false, priority = 43 }
```

#### `google_whitelist_config`, `parsely_whitelist_config`, `k6_whitelist_config` removed

The module no longer fetches bot IP ranges internally. Use the `ip_list_fetcher` submodule to fetch them externally and pass them via `ip_whitelisting`.

```hcl
# Before
google_whitelist_config = {
  enable        = true
  insert_header = { "set-premium" = "true" }
}

# After
module "googlebot_ips" {
  source = "tx-pts-dai/waf/aws//modules/ip_list_fetcher"
  urls   = ["https://developers.google.com/search/apis/ipranges/googlebot.json"]
}

ip_whitelisting = {
  googlebot = {
    ips                = module.googlebot_ips.ipv4
    ip_address_version = "IPV4"
    priority           = 10
    insert_header      = { "set-premium" = "true" }
  }
}
```

### New features

#### Configurable priorities for `everybody_else_config`, `blocked_headers`, `count_requests_from_ch`

All three variables now accept an optional `priority` field, giving callers full control over WAF ACL rule ordering without needing to touch the module internals.

#### `country_rates` — unlimited rules via chunked rule groups

`country_rates` rules are now deployed inside WAF rule groups, automatically split into chunks of 4. This removes the previous limit on the number of country rate rules. Priorities in `var.country_rates` are scoped to the rule group, not the Web ACL.

---

# 📣 Major Update Changelog (v7.0.0)

## ⚠️ **Breaking Change: Refactor of IP Whitelisting Variables**

This major update introduces a complete overhaul of how custom and service-specific IP whitelisting is configured. **All users must update their Terraform configurations** when upgrading to this version, unless the implicated variables were not used in the module declaration.

### Variable Changes:

| Old Variable(s) | New Variable | Description |
| :--- | :--- | :--- |
| `whitelisted_ips_v4`, `whitelisted_ips_v6` | **`ip_whitelisting`** | **Replaced** by a single `map(object)` variable allowing for *multiple, named whitelists* with individual priority, IP version (`IPV4`/`IPV6`), and header insertion configuration. |
|  | | |
| `enable_google_bots_whitelist`, `google_bots_url` | **`google_whitelist_config`** | **Replaced** by an `object` that consolidates the `enable`, `url`, and new optional `insert_header` fields. |
|  | | |
| `enable_parsely_crawlers_whitelist`, `parsely_crawlers_url` | **`parsely_whitelist_config`** | **Replaced** by an `object` that consolidates the `enable`, `url`, and new optional `insert_header` fields. |
|  | | |
| `enable_k6_whitelist`, `k6_ip_ranges_url` | **`k6_whitelist_config`** | **Replaced** by an `object` that consolidates the `enable`, `url`, and new optional `insert_header` fields. |

#### New variables details
  * **New Type:**
    ```hcl
    variable "ip_whitelisting" {
      description = "Map of configurations for whitelisting custom lists of IPs. Use 'insert_header' to add custom headers to these requests (the headers will be prefixed automatically with `x-amzn-waf-`)."
      default     = {}
      type = map(object({
        ips                = list(string)
        ip_address_version = string # possible values: IPV4, IPV6
        priority           = number # > 10
        insert_header      = optional(map(string), null)
      }))
    }

    variable "google_whitelist_config" {
      description = "Configuration for whitelisting Googlebot IPs. Set 'whitelist' to false to disable the whitelisting. Doc https://developers.google.com/search/apis/ipranges/googlebot.json. The IPs are automatically parsed from the given url. Use 'insert_header' to add custom headers to these requests (the headers will be prefixed automatically with `x-amzn-waf-`)."
      default     = null
      type = object({
        enable        = optional(bool, false)
        url           = optional(string, "https://developers.google.com/search/apis/ipranges/googlebot.json")
        insert_header = optional(map(string), null)
      })
    }
    variable "parsely_whitelist_config" {...}   # similar to var.google_whitelist_config
    variable "k6_whitelist_config" {...}        # similar to var.google_whitelist_config
    ```

### Rule Priorities

  The **priorities of several WAF rules** within the module have been adjusted. User action are might be required when updating to this version. Changes are:

  ```diff
  ## Priorities:
  # 0: block_based_on_headers
  -# 1: limit_search_requests_by_countries
  -# 2-10: block_uri_path_string
  +# 1: whitelist_group
  +# 2: limit_search_requests_by_countries
  +# 3-10: block_uri_path_string
  # 11-20: block_articles
  # 21-30: block_regex_pattern
  -# 31-39 free
  -# 40: whitelisted_ips_v4
  -# 41: whitelisted_ips_v6
  +# 32-41 free
  # 42: Rate_limit_everything_apart_from_CH
  # 43: count_requests_from_ch
  # 44: whitelist_based_on_headers
  ```

### Key Features & Improvements:

  * **Configurable Headers on Whitelisted Requests:** All whitelisting configurations (custom, Google, Parse.ly, k6) now support an optional `insert_header` map. This allows the module to automatically insert a custom header (prefixed with `x-amzn-waf-`) upon a successful whitelist match, aiding in request tracing and downstream processing.
  * **Multi-CIDR Custom Whitelisting:** The new `ip_whitelisting` variable allows defining multiple, distinct whitelists with separate priorities, giving users granular control over IP-based exceptions.
  * **Rule Priority Optimization:** The **priorities of several WAF rules** within the module have been adjusted. User action are required when updating to this version. Changes are:
