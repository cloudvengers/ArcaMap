resource "aws_iam_role" "ec2" {
  for_each = {
    api           = "arcamap-api-ec2"
    image_builder = "arcamap-imagebuilder-ec2"
  }

  name = each.value
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  for_each = aws_iam_role.ec2

  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  for_each = aws_iam_role.ec2

  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "image_builder" {
  role       = aws_iam_role.ec2["image_builder"].name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

resource "aws_iam_role_policy" "imagebuilder_log_test" {
  name = "arcamap-imagebuilder-log-test"
  role = aws_iam_role.ec2["image_builder"].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "logs:FilterLogEvents"
      Resource = "${module.log_groups["ec2_system"].log_group.arn}:*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  for_each = {
    api           = var.ec2_instance_profile_name
    image_builder = var.image_builder_instance_profile_name
  }

  name = each.value
  role = aws_iam_role.ec2[each.key].name

  # 프로파일을 사용하는 이미지 빌드·EC2 시작 전에 권한 연결을 완료합니다.
  depends_on = [
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy_attachment.cloudwatch,
    aws_iam_role_policy_attachment.image_builder,
    aws_iam_role_policy.imagebuilder_log_test,
  ]
}

resource "aws_iam_role_policy" "api_secret" {
  for_each = aws_iam_role.ec2

  name = "arcamap-api-database-secret"
  role = each.value.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.database.arn
    }]
  })
}

resource "aws_iam_role_policy" "imagebuilder_artifact" {
  name = "arcamap-imagebuilder-artifact"
  role = aws_iam_role.ec2["image_builder"].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:GetObject"
      Resource = "${module.deployment_bucket.bucket.arn}/${local.api_artifact_key}"
    }]
  })
}
