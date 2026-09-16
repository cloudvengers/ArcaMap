resource "aws_cloudwatch_log_group" "main" {
  name              = var.name
  retention_in_days = var.log_retention_days
  log_group_class   = "STANDARD"
}
