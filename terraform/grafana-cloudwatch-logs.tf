# create the grafana_loki_s3_bucket s3 bucket
resource "aws_s3_bucket" "grafana_loki_s3_bucket" {
  bucket = var.grafana_loki_s3_bucket
  acl    = "private"
}

resource "aws_s3_object_copy" "lambda_promtail_zipfile" {
  bucket = aws_s3_bucket.grafana_loki_s3_bucket.bucket
  key    = var.grafana_loki_s3_key
  source = "grafanalabs-cf-templates/lambda-promtail/lambda-promtail.zip"
}

resource "aws_iam_role" "lambda_promtail_role" {
  name = "GrafanaLabsCloudWatchLogsIntegration"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Effect" : "Allow",
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_promtail_policy_logs" {
  name = "lambda-logs"
  role = aws_iam_role.lambda_promtail_role.name
  policy = jsonencode({
    "Statement" : [
      {
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:logs:*:*:*",
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda_promtail_log_group" {
  name              = "/aws/lambda/GrafanaCloudLambdaPromtail"
  retention_in_days = 14
}

resource "aws_lambda_function" "lambda_promtail" {
  function_name = "GrafanaCloudLambdaPromtail"
  role          = aws_iam_role.lambda_promtail_role.arn

  timeout     = 60
  memory_size = 128

  handler   = "main"
  runtime   = "go1.x"
  s3_bucket = aws_s3_bucket.grafana_loki_s3_bucket.bucket
  s3_key    = var.grafana_loki_s3_key

  environment {
    variables = {
      WRITE_ADDRESS = var.grafana_loki_write_address
      USERNAME      = var.grafana_loki_username
      PASSWORD      = var.grafana_loki_password
      KEEP_STREAM   = var.grafana_loki_keep_stream_value_label
      BATCH_SIZE    = var.grafana_loki_batch_size
      EXTRA_LABELS  = var.grafana_loki_extra_labels
    }
  }

  depends_on = [
    aws_s3_object_copy.lambda_promtail_zipfile,
    aws_iam_role_policy.lambda_promtail_policy_logs,
    aws_cloudwatch_log_group.lambda_promtail_log_group,
  ]
}

resource "aws_lambda_function_event_invoke_config" "lambda_promtail_invoke_config" {
  function_name          = aws_lambda_function.lambda_promtail.function_name
  maximum_retry_attempts = 2
}

resource "aws_lambda_permission" "lambda_promtail_allow_cloudwatch" {
  statement_id  = "lambda-promtail-allow-cloudwatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_promtail.function_name
  principal     = "logs.${data.aws_region.current.name}.amazonaws.com"
}

# This block allows for easily subscribing to multiple log groups via the `cloudwatch_logs_group_names` var.
# However, if you need to provide an actual filter_pattern for a specific log group you should
# copy this block and modify it accordingly.
resource "aws_cloudwatch_log_subscription_filter" "lambda_promtail_logfilter" {
  for_each        = toset(var.cloudwatch_logs_group_names)
  name            = "lambda_promtail_logfilter_${each.value}"
  log_group_name  = each.value
  destination_arn = aws_lambda_function.lambda_promtail.arn
  # required but can be empty string
  filter_pattern = ""
  depends_on     = [aws_iam_role_policy.lambda_promtail_policy_logs]
}

output "grafana_cloudwatch_logs_role_arn" {
  value       = aws_lambda_function.lambda_promtail.arn
  description = "The ARN of the Lambda function that runs lambda-promtail."
}

variable "grafana_loki_write_address" {
  type        = string
  description = "This is the Grafana Cloud Loki URL that logs will be forwarded to."
  default     = ""
}

variable "grafana_loki_username" {
  type        = string
  description = "The basic auth username for Grafana Cloud Loki."
  default     = ""
}

variable "grafana_loki_password" {
  type        = string
  description = "The basic auth password for Grafana Cloud Loki (your Grafana.com API Key)."
  sensitive   = true
  default     = ""
}

variable "grafana_loki_s3_bucket" {
  type        = string
  description = "The name of the bucket where to upload the 'lambda-promtail.zip' file."
  default     = ""
}

variable "grafana_loki_s3_key" {
  type        = string
  description = "The desired path where to upload the 'lambda-promtail.zip' file (defaults to the root folder)."
  default     = "lambda-promtail.zip"
}

variable "cloudwatch_logs_group_names" {
  type        = list(string)
  description = "List of CloudWatch Log Group names to create Subscription Filters for (ex. /aws/lambda/my-log-group)."
  default     = []
}

variable "grafana_loki_keep_stream_value_label" {
  type        = string
  description = "Determines whether to keep the CloudWatch Log Stream value as a Loki label when writing logs from lambda-promtail."
  default     = "false"
}

variable "grafana_loki_extra_labels" {
  type        = string
  description = "Comma separated list of extra labels, in the format 'name1,value1,name2,value2,...,nameN,valueN' to add to entries forwarded by lambda-promtail."
  default     = ""
}

variable "grafana_loki_batch_size" {
  type        = string
  description = "Determines when to flush the batch of logs (bytes)."
  default     = ""
}
