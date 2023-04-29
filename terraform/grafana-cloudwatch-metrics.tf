locals {
  grafana_account_id = "008923505280"
}
variable "grafana_cloud_external_id" {
  type        = string
  description = "This is your Grafana Cloud identifier and is used for security purposes."
  validation {
    condition     = length(var.grafana_cloud_external_id) > 0
    error_message = "ExternalID is required."
  }
}
variable "grafana_cloudwatch_metrics_iam_role_name" {
  type        = string
  default     = "GrafanaLabsCloudWatchIntegration"
  description = "Customize the name of the IAM role used by Grafana for the CloudWatch integration."
}
data "aws_iam_policy_document" "trust_grafana" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.grafana_account_id}:root"]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.grafana_cloud_external_id]
    }
  }
}
resource "aws_iam_role" "grafana_labs_cloudwatch_integration" {
  name        = var.grafana_cloudwatch_metrics_iam_role_name
  description = "Role used by Grafana CloudWatch integration."
  # Allow Grafana Labs' AWS account to assume this role.
  assume_role_policy = data.aws_iam_policy_document.trust_grafana.json

  # This policy allows the role to discover metrics via tags and export them.
  inline_policy {
    name = var.grafana_cloudwatch_metrics_iam_role_name
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "tag:GetResources",
            "cloudwatch:GetMetricData",
            "cloudwatch:GetMetricStatistics",
            "cloudwatch:ListMetrics"
          ]
          Resource = "*"
        }
      ]
    })
  }
}
output "grafana_cloudwatch_metrics_role_arn" {
  value       = aws_iam_role.grafana_labs_cloudwatch_integration.arn
  description = "The ARN for the role created, copy this into Grafana Cloud installation."
}
