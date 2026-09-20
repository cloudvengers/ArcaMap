resource "aws_launch_template" "api" {
  name                   = "arcamap-api"
  image_id               = var.image.id
  instance_type          = var.ec2_instance_type
  vpc_security_group_ids = [var.api_security_group_id]

  iam_instance_profile {
    name = var.ec2_instance_profile_name
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  block_device_mappings {
    device_name = var.image.root_device_name

    ebs {
      volume_type           = "gp3"
      volume_size           = var.ec2_root_volume_size
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = false
  }

  user_data = base64encode(<<-BASH
    #!/bin/bash
    set -euo pipefail
    ${var.cloudwatch_agent_start}
  BASH
  )
}

resource "aws_autoscaling_group" "api" {
  count = 1

  name                      = "arcamap-api"
  min_size                  = 2
  max_size                  = var.asg_max_size
  health_check_type         = var.asg_health_check_type
  health_check_grace_period = 300
  default_instance_warmup   = 300
  vpc_zone_identifier       = var.api_subnet_ids
  target_group_arns         = [var.target_group_arn]
  enabled_metrics           = ["GroupInServiceInstances", "GroupDesiredCapacity"]
  metrics_granularity       = "1Minute"

  availability_zone_distribution {
    capacity_distribution_strategy = "balanced-best-effort"
  }

  launch_template {
    id      = aws_launch_template.api.id
    version = aws_launch_template.api.latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      # ponytail: 개발 중에는 교체 시 API 중단을 허용합니다. 무중단 배포 전환 시 유지 비율을 높입니다.
      min_healthy_percentage = 0
      max_healthy_percentage = 100
      instance_warmup        = 300
      skip_matching          = true
    }
  }

}

resource "aws_autoscaling_policy" "api_cpu" {
  count = length(aws_autoscaling_group.api)

  name                   = "arcamap-api-cpu"
  autoscaling_group_name = aws_autoscaling_group.api[count.index].name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value     = var.asg_cpu_target
    disable_scale_in = false

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}
