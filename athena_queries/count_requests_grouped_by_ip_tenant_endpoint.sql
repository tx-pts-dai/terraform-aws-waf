/*
This query count requests grouped by the ip, terminating rule, action, endpoint and tenant
*/
WITH test_dataset AS
  (SELECT httprequest.clientip, terminatingruleid, action, httprequest.uri, header FROM waf_logs
    CROSS JOIN UNNEST(httprequest.headers) AS t(header) where (action='BLOCK')  and (terminatingruleid='Group_1-CH'))
SELECT COUNT(*) as count, clientip, terminatingruleid, action, uri, header.value as tenant
FROM test_dataset
WHERE LOWER(header.name)='host'
GROUP BY clientip, terminatingruleid, action, uri, header.value
ORDER BY count DESC
