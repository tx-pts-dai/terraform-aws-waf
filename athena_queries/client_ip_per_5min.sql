/*
This queries comes from aws documentation https://docs.aws.amazon.com/athena/latest/ug/waf-logs.html
The following query counts, for a particular date range, the number of IP addresses in five minute intervals.
*/
WITH dataset AS
  (SELECT
     format_datetime(from_unixtime((timestamp/1000) - ((minute(from_unixtime(timestamp / 1000))%5) * 60)),'yyyy-MM-dd HH:mm') AS five_minutes_ts,
     "httprequest"."clientip"
     FROM waf_logs
     -- Sete the range time you are interested in
     WHERE date >= '2022/10/01' AND date < '2022/10/10')
SELECT five_minutes_ts,"clientip",count(*) ip_count
FROM dataset
GROUP BY five_minutes_ts,"clientip"
