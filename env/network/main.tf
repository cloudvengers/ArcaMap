module "network" {                 # 공통 네트워크 모듈 연결
  source = "../../modules/network" # 로컬 하위 모듈 경로
}                                  # 설정 묶음 끝

module "security" {                 # 통신 보안 그룹 모듈 연결
  source = "../../modules/security" # 로컬 하위 모듈 경로

  vpc_id = module.network.vpc_id # 리소스를 연결할 VPC ID
}                                # 설정 묶음 끝

resource "aws_sns_topic" "operations" {
  name       = "arcamap-operations"
  fifo_topic = false
}

locals {
  notification_topic_arn_parts = split(":", aws_sns_topic.operations.arn)
}

resource "aws_sns_topic_policy" "operations" {
  arn = aws_sns_topic.operations.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowArcamapCloudWatchAlarms"
      Effect    = "Allow"
      Principal = { Service = "cloudwatch.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.operations.arn
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.notification_topic_arn_parts[4] }
        ArnLike = {
          "aws:SourceArn" = "arn:${local.notification_topic_arn_parts[1]}:cloudwatch:${local.notification_topic_arn_parts[3]}:${local.notification_topic_arn_parts[4]}:alarm:arcamap-*"
        }
      }
    }]
  })
}

resource "aws_sns_topic_subscription" "operations" {
  topic_arn = aws_sns_topic.operations.arn
  protocol  = "email"
  endpoint  = var.notification_email

  # 수신자는 배포 후 SNS 확인 이메일에서 구독을 승인해야 합니다.
  endpoint_auto_confirms = false
}
