# Parse.ly is an analytics tool used by the Disco team. The use case for whitelisting their crawlers is that they might need to
# trigger a large crawl after a wrong update to the metadata of the articles
locals {
  parsely_whitelist_json = var.parsely_whitelist_config.enable ? jsondecode(data.http.parsely_ip_list[0].response_body) : "{}"
  parsely_crawlers       = var.parsely_whitelist_config.enable ? compact([for ip in local.parsely_whitelist_json : "${ip}/32"]) : []
}


data "http" "parsely_ip_list" {
  count = var.parsely_whitelist_config.enable ? 1 : 0

  url = var.parsely_whitelist_config.url

  request_headers = merge(
    {
      Accept       = "application/json"
      "User-Agent" = "terraform-http"
    },
    var.parsely_whitelist_config.http_call_extra_headers
  )
}
