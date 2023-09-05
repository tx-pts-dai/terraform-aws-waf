locals {
  # Parse https://www.oracle.com/corporate/acquisitions/grapeshot/crawler.html to obtain the list of IPs
  # oracle_ips_html parses the raw html list of IPs
  oracle_ips_html = var.enable_oracle_crawler_whitelist ? regexall("<li>\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}</li>", data.http.oracle.response_body) : []
  # oracle_ip_ranges_html parses the raw html list of IP ranges
  oracle_ip_ranges_html = var.enable_oracle_crawler_whitelist ? regexall("<li>\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3} to \\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}</li>", data.http.oracle.response_body) : []
  # oracle_ip_ranges cleanup IP ranges and creates a list of touble with start and end of range
  oracle_ip_ranges = [
    for ips in local.oracle_ip_ranges_html :
    split(" to ", trimprefix(trimsuffix(ips, "</li>"), "<li>"))
  ]
  # oracle_ip_ranges_expanded expands the ranges creating all the IPs from start to end
  # tonumber(regex("\\d{1,3}$", l[0]) takes the first item in the touple of each oracle_ip_ranges
  # and gets the rightmost number (starting point for the list of IPs)
  # similarly tonumber(regex("\\d{1,3}$", l[2]) takes the last item in the touple of each oracle_ip_ranges
  # and gets the rightmost number (ending point for the list of IPs)
  # format("%s%d", regex("\\d{1,3}.\\d{1,3}.\\d{1,3}.", l[0]), x) then creates the complete range of IPs
  oracle_ip_ranges_expanded = [
    for l in local.oracle_ip_ranges : [
      for x in range(tonumber(regex("\\d{1,3}$", l[0])), tonumber(regex("\\d{1,3}$", l[1])) + 1) :
      format("%s%d", regex("\\d{1,3}.\\d{1,3}.\\d{1,3}.", l[0]), x)
    ]
  ]
  # oracle_ips cleans up oracle_ips_html and concatenate with oracle_ip_ranges_expanded
  oracle_ips = concat([
    for ip in local.oracle_ips_html :
    trimprefix(trimsuffix(ip, "</li>"), "<li>")
    ],
    flatten(local.oracle_ip_ranges_expanded)
  )

  oracle_data_cloud_crawlers = [
    for ip in local.oracle_ips : format("%s%s", ip, "/32")
  ]
}

data "http" "oracle" {
  url = var.oracle_data_cloud_crawlers_url

  request_headers = {
    Accept = "text/html"
  }
}
