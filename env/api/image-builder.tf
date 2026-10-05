module "image_builder" {
  count  = var.enable_image_builder ? 1 : 0
  source = "../../modules/image-builder"

  api_subnet_id                       = data.aws_subnet.api.id
  image_builder_security_group_id     = data.aws_security_group.image_builder.id
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
    artifact_uri       = "s3://${aws_s3_object.api[0].bucket}/${aws_s3_object.api[0].key}"
    artifact_sha256    = local.api_artifact_sha256
    service_base64     = base64encode(local.api_service)
    environment_base64 = base64encode(local.api_environment)
    db_test_user       = local.database_roles.image_builder
  }
}
