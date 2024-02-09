# Parse.ly is an analytics tool used by the Disco team. The use case for whitelisting their crawlers is that they might need to
# trigger a large recrawl after a wrong update to the metadata of the articles
locals {
  parsely_whitelist_json = jsondecode(data.http.parsely_ip_list.response_body)
  parsely_crawlers       = var.enable_parsely_crawlers_whitelist ? [for ip in local.parsely_whitelist_json : "${ip}/32"] : []
}


data "http" "parsely_ip_list" {
  url = var.parsely_crawlers_url

  request_headers = {
    Accept = "application/json"
  }
}
