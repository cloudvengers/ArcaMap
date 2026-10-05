module "compute" {
  count  = var.api_image == null ? 0 : 1
  source = "../../modules/compute"

  api_subnet_ids        = [data.aws_subnet.api.id]
  api_security_group_id = data.aws_security_group.api.id
  image = {
    id               = data.aws_ami.api[0].id
    root_device_name = data.aws_ami.api[0].root_device_name
    root_volume_size = one([for device in data.aws_ami.api[0].block_device_mappings : device.ebs.volume_size if device.device_name == data.aws_ami.api[0].root_device_name])
  }
  target_group_arn          = module.alb.alb.target_group_arn
  ec2_instance_profile_name = aws_iam_instance_profile.ec2["api"].name
  ec2_instance_type         = var.ec2_instance_type
  ec2_root_volume_size      = var.ec2_root_volume_size
  asg_max_size              = var.asg_max_size
  asg_cpu_target            = var.asg_cpu_target
  asg_name                  = local.api_asg_name
  instance_refresh_alarm_names = [
    module.service_alarms["alb-healthy-hosts"].name,
    module.service_alarms["alb-5xx"].name,
    module.service_alarms["api-5xx"].name,
  ]
  asg_memory_target      = var.asg_memory_target
  asg_health_check_type  = var.asg_health_check_type
  cloudwatch_agent_start = local.cloudwatch_agent_start
}
