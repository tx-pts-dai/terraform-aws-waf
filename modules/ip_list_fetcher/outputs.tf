output "ipv4_addresses" {
  description = "List of IPv4 CIDR ranges parsed from the fetched IP list."
  value       = local.ipv4_addresses
}

output "ipv6_addresses" {
  description = "List of IPv6 CIDR ranges parsed from the fetched IP list."
  value       = local.ipv6_addresses
}
