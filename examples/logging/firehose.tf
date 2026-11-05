resource "aws_kinesis_firehose_delivery_stream" "waf_logs" {
  name        = "aws-waf-logs-${local.waf_name}"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = aws_s3_bucket.logs.arn
    prefix              = "parquet/!{timestamp:yyyy/MM/dd}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/!{timestamp:yyyy/MM/dd}/"
    buffering_size      = 64
    buffering_interval  = 300

    data_format_conversion_configuration {
      input_format_configuration {
        deserializer {
          open_x_json_ser_de {}
        }
      }

      output_format_configuration {
        serializer {
          parquet_ser_de {
            compression = "SNAPPY"
          }
        }
      }

      schema_configuration {
        role_arn      = aws_iam_role.firehose.arn
        database_name = aws_glue_catalog_table.waf_logs.database_name
        table_name    = aws_glue_catalog_table.waf_logs.name
      }
    }
  }
}

data "aws_iam_policy_document" "firehose_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "firehose" {
  name               = "${local.waf_name}-firehose"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume.json
}

data "aws_iam_policy_document" "firehose" {
  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
    ]
    resources = [aws_s3_bucket.logs.arn, "${aws_s3_bucket.logs.arn}/*"]
  }

  statement {
    actions = ["glue:GetTable", "glue:GetTableVersion", "glue:GetTableVersions"]
    resources = [
      "arn:aws:glue:*:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:aws:glue:*:${data.aws_caller_identity.current.account_id}:database/${aws_glue_catalog_database.waf.name}",
      "arn:aws:glue:*:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.waf.name}/*",
    ]
  }
}

resource "aws_iam_role_policy" "firehose" {
  role   = aws_iam_role.firehose.id
  policy = data.aws_iam_policy_document.firehose.json
}
