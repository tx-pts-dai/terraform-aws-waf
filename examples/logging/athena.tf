resource "aws_glue_catalog_database" "waf" {
  name = "waf_logs_${local.db_name}"
}

resource "aws_glue_catalog_table" "waf_logs" {
  name          = "waf_logs"
  database_name = aws_glue_catalog_database.waf.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "classification"                = "parquet"
    "projection.enabled"            = "true"
    "projection.date.type"          = "date"
    "projection.date.range"         = "2026/01/01,NOW"
    "projection.date.format"        = "yyyy/MM/dd"
    "projection.date.interval"      = "1"
    "projection.date.interval.unit" = "DAYS"
    "storage.location.template"     = "s3://${aws_s3_bucket.logs.id}/parquet/$${date}/"
  }

  partition_keys {
    name = "date"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.logs.id}/parquet/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    dynamic "columns" {
      for_each = local.waf_log_columns
      content {
        name = columns.key
        type = columns.value
      }
    }
  }
}

locals {
  waf_log_columns = {
    timestamp                   = "bigint"
    formatversion               = "int"
    webaclid                    = "string"
    terminatingruleid           = "string"
    terminatingruletype         = "string"
    action                      = "string"
    terminatingrulematchdetails = "array<struct<conditiontype:string,location:string,matcheddata:array<string>>>"
    httpsourcename              = "string"
    httpsourceid                = "string"
    rulegrouplist               = "array<struct<rulegroupid:string,terminatingrule:struct<ruleid:string,action:string,rulematchdetails:string>,nonterminatingmatchingrules:array<string>,excludedrules:string>>"
    ratebasedrulelist           = "array<struct<ratebasedruleid:string,limitkey:string,maxrateallowed:int>>"
    nonterminatingmatchingrules = "array<struct<ruleid:string,action:string>>"
    requestheadersinserted      = "string"
    responsecodesent            = "string"
    httprequest                 = "struct<clientip:string,country:string,headers:array<struct<name:string,value:string>>,uri:string,args:string,httpversion:string,httpmethod:string,requestid:string>"
    labels                      = "array<struct<name:string>>"
    captcharesponse             = "struct<responsecode:string,solvetimestamp:string,failurereason:string>"
  }

  named_queries = {
    "requests-per-client-ip-per-5min"              = "client_ip_per_5min.sql"
    "count-requests-grouped-by-ip-tenant-endpoint" = "count_requests_grouped_by_ip_tenant_endpoint.sql"
    "requests-blocked"                             = "blocked_requests.sql"
    "requests-blocked-per-client-ip"               = "per_ip_blocked_requests.sql"
  }
}

resource "aws_athena_workgroup" "waf" {
  name          = "waf-logs-${local.waf_name}"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.logs.bucket}/query-results/"
    }
  }
}

resource "aws_athena_named_query" "waf" {
  for_each  = local.named_queries
  name      = "${each.key}-${local.waf_name}"
  workgroup = aws_athena_workgroup.waf.id
  database  = aws_glue_catalog_database.waf.name
  query     = file("${path.module}/athena_queries/${each.value}")
}
