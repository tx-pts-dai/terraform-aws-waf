SELECT
  "httprequest"."clientip"
, "count"(*) "count"
,"httprequest"."country"
FROM
 waf_logs
WHERE ("action" LIKE
'BLOCK')
GROUP BY
"httprequest"."clientip", "httprequest"."country"
ORDER BY "count" DESC
