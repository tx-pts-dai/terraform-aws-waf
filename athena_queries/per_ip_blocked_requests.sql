/*
This query gets all the blocked requests for a given IP (works for both IPV4 and IPV6) in a give time range
*/
SELECT * 
FROM waf_logs
WHERE httprequest.clientip='2a02:121e:7823:0:bc4c:e549:9ae0:c93a' AND "date" >= '2022/11/03' AND "date" < '2022/11/04' AND ("action" LIKE 'BLOCK')
