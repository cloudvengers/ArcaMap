data "aws_vpc" "main" {
  tags = { Name = "arcamap-vpc" }
}

data "aws_subnet" "public" {
  for_each = toset(["ap-northeast-2a", "ap-northeast-2c"])

  vpc_id            = data.aws_vpc.main.id
  availability_zone = each.key
  tags              = { Name = "arcamap-public-${each.key}" }
}

data "aws_subnet" "api" {
  for_each = toset(["ap-northeast-2a", "ap-northeast-2c"])

  vpc_id            = data.aws_vpc.main.id
  availability_zone = each.key
  tags              = { Name = "arcamap-api-${each.key}" }
}

data "aws_security_group" "alb" {
  name   = "arcamap-alb"
  vpc_id = data.aws_vpc.main.id
}

data "aws_security_group" "api" {
  name   = "arcamap-api"
  vpc_id = data.aws_vpc.main.id
}

data "aws_acm_certificate" "api" {
  domain      = var.api_domain_name
  statuses    = ["ISSUED"]
  most_recent = false
}

data "aws_db_instance" "postgres" {
  db_instance_identifier = "arcamap-postgres"
}

locals {
  cloudwatch_agent_start = "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/arcamap-cloudwatch-agent.json"

  # ponytail: API log path and format are not defined; add files.collect_list when the API is ready.
  cloudwatch_agent_config = {
    logs = {
      logs_collected = {
        journald = {
          collect_list = [{
            log_group_name  = module.log_groups["ec2_system"].log_group.name
            log_stream_name = "{instance_id}/system"
            priority        = "info"
          }]
        }
      }
    }
  }

  service_alarms = {
    "asg-inservice" = {
      namespace           = "AWS/AutoScaling"
      metric_name         = "GroupInServiceInstances"
      statistic           = "Minimum"
      threshold           = 2
      comparison_operator = "LessThanThreshold"
      period              = 60
      datapoints_to_alarm = 2
      evaluation_periods  = 3
      treat_missing_data  = "missing"
      dimensions          = { AutoScalingGroupName = module.compute.autoscaling_group.name }
    }
    "ec2-status-check" = {
      namespace           = "AWS/EC2"
      metric_name         = "StatusCheckFailed"
      statistic           = "Maximum"
      threshold           = 1
      comparison_operator = "GreaterThanOrEqualToThreshold"
      period              = 60
      datapoints_to_alarm = 2
      evaluation_periods  = 3
      treat_missing_data  = "missing"
      dimensions          = { AutoScalingGroupName = module.compute.autoscaling_group.name }
    }
    "ec2-cpu" = {
      namespace           = "AWS/EC2"
      metric_name         = "CPUUtilization"
      statistic           = "Average"
      threshold           = 80
      comparison_operator = "GreaterThanOrEqualToThreshold"
      period              = 300
      datapoints_to_alarm = 3
      evaluation_periods  = 3
      treat_missing_data  = "missing"
      dimensions          = { AutoScalingGroupName = module.compute.autoscaling_group.name }
    }
    "alb-healthy-hosts" = {
      namespace           = "AWS/ApplicationELB"
      metric_name         = "HealthyHostCount"
      statistic           = "Minimum"
      threshold           = 2
      comparison_operator = "LessThanThreshold"
      period              = 60
      datapoints_to_alarm = 2
      evaluation_periods  = 3
      treat_missing_data  = "missing"
      dimensions          = { LoadBalancer = module.alb.alb.arn_suffix, TargetGroup = module.alb.alb.target_group_arn_suffix }
    }
    "alb-5xx" = {
      namespace           = "AWS/ApplicationELB"
      metric_name         = "HTTPCode_ELB_5XX_Count"
      statistic           = "Sum"
      threshold           = 5
      comparison_operator = "GreaterThanOrEqualToThreshold"
      period              = 300
      datapoints_to_alarm = 1
      evaluation_periods  = 1
      treat_missing_data  = "notBreaching"
      dimensions          = { LoadBalancer = module.alb.alb.arn_suffix }
    }
    "api-5xx" = {
      namespace           = "AWS/ApplicationELB"
      metric_name         = "HTTPCode_Target_5XX_Count"
      statistic           = "Sum"
      threshold           = 5
      comparison_operator = "GreaterThanOrEqualToThreshold"
      period              = 300
      datapoints_to_alarm = 1
      evaluation_periods  = 1
      treat_missing_data  = "notBreaching"
      dimensions          = { LoadBalancer = module.alb.alb.arn_suffix, TargetGroup = module.alb.alb.target_group_arn_suffix }
    }
  }
}

module "log_groups" {
  for_each = {
    ec2_system   = "/arcamap/ec2/system"
    api          = "/arcamap/api/application"
    alb          = "/aws/vendedlogs/elb/arcamap-api"
    imagebuilder = "/aws/imagebuilder/arcamap-api"
  }
  source = "../../modules/cloudwatch-log-group"

  name               = each.value
  log_retention_days = var.log_retention_days
}

module "alb" {
  source = "../../modules/alb"

  vpc_id                = data.aws_vpc.main.id
  public_subnet_ids     = [for subnet in data.aws_subnet.public : subnet.id]
  alb_security_group_id = data.aws_security_group.alb.id
  certificate_arn       = data.aws_acm_certificate.api.arn
  log_group_arn         = module.log_groups["alb"].log_group.arn
}

resource "aws_route53_record" "api" {
  provider = aws.dns

  zone_id         = var.route53_zone_id
  name            = var.api_domain_name
  type            = "A"
  allow_overwrite = false

  alias {
    name                   = "dualstack.${module.alb.alb.dns_name}"
    zone_id                = module.alb.alb.zone_id
    evaluate_target_health = true
  }
}

module "image_builder" {
  source = "../../modules/image-builder"

  api_subnet_id                       = data.aws_subnet.api["ap-northeast-2a"].id
  api_security_group_id               = data.aws_security_group.api.id
  image_builder_instance_profile_name = aws_iam_instance_profile.ec2["image_builder"].name
  image_builder_instance_type         = var.image_builder_instance_type
  image_builder_root_volume_size      = var.image_builder_root_volume_size
  image_builder_version               = var.image_builder_version
  cloudwatch_agent_version            = var.cloudwatch_agent_version
  cloudwatch_agent_config_json        = jsonencode(local.cloudwatch_agent_config)
  cloudwatch_agent_start              = local.cloudwatch_agent_start
  system_log_group_name               = module.log_groups["ec2_system"].log_group.name
  imagebuilder_log_group_name         = module.log_groups["imagebuilder"].log_group.name
  api_installation = {
    artifact_uri         = "s3://${aws_s3_object.api.bucket}/${aws_s3_object.api.key}"
    artifact_sha256      = filesha256(local.api_artifact_path)
    service_base64       = filebase64("${path.module}/../../../was/deploy/arcamap-api.service")
    secret_loader_base64 = filebase64("${path.module}/../../../was/deploy/load-runtime-env.sh")
    rds_ca_base64        = filebase64("${path.module}/../../../data/rds-ap-northeast-2-bundle.pem")
    secret_arn           = aws_secretsmanager_secret.database.arn
  }
}

module "compute" {
  source = "../../modules/compute"

  api_subnet_ids            = [for subnet in data.aws_subnet.api : subnet.id]
  api_security_group_id     = data.aws_security_group.api.id
  image                     = module.image_builder.image
  target_group_arn          = module.alb.alb.target_group_arn
  ec2_instance_profile_name = aws_iam_instance_profile.ec2["api"].name
  ec2_instance_type         = var.ec2_instance_type
  ec2_root_volume_size      = var.ec2_root_volume_size
  asg_max_size              = var.asg_max_size
  asg_cpu_target            = var.asg_cpu_target
  asg_health_check_type     = var.asg_health_check_type
  cloudwatch_agent_start    = local.cloudwatch_agent_start
}

module "service_alarms" {
  for_each = local.service_alarms
  source   = "../../modules/cloudwatch-alarm"

  name  = "arcamap-${each.key}"
  alarm = each.value
}
