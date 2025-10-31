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
