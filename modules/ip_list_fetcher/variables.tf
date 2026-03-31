variable "url" {
  description = "URL to fetch the IP list JSON from."
  type        = string
}

variable "request_headers" {
  description = "Additional HTTP request headers to send alongside the default Accept and User-Agent headers."
  type        = map(string)
  default     = {}
}

variable "root_key" {
  description = "Key at the JSON root that contains the array of entries (e.g. \"prefixes\"). Leave empty when the root itself is the array."
  type        = string
  default     = ""
}

variable "ipv4_key" {
  description = "Key within each array entry that holds the IPv4 CIDR string (e.g. \"ipv4Prefix\", \"ip_prefix\"). Leave empty when there are no IPv4 entries to extract via a key lookup."
  type        = string
  default     = ""
}

variable "ipv6_key" {
  description = "Key within each array entry that holds the IPv6 CIDR string (e.g. \"ipv6Prefix\"). Leave empty when there are no IPv6 entries."
  type        = string
  default     = ""
}

variable "flat_array" {
  description = "Set to true when the JSON array contains plain IP strings rather than objects (e.g. Parse.ly format: [\"1.2.3.4\", ...])."
  type        = bool
  default     = false
}

variable "flat_cidr_prefix" {
  description = "CIDR prefix length to append to each IP when flat_array = true (e.g. 32 yields \"1.2.3.4/32\"). When null, IPs are used as-is."
  type        = number
  default     = null
}

variable "filter" {
  description = "Optional key/value filter applied to array entries before extracting IPs (e.g. { key = \"region\", value = \"eu-central-1\" })."
  type = object({
    key   = string
    value = string
  })
  default = null
}
