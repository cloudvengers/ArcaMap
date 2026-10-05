resource "aws_imagebuilder_image_recipe" "api" {
  name         = "arcamap-api"
  parent_image = data.aws_ami.ubuntu.id
  version      = var.image_builder_version

  component {
    component_arn = aws_imagebuilder_component.base.arn
  }

  component {
    component_arn = aws_imagebuilder_component.fastapi.arn
  }

  component {
    component_arn = aws_imagebuilder_component.test.arn
  }

  component {
    component_arn = aws_imagebuilder_component.fastapi_test.arn
  }

  block_device_mapping {
    device_name = data.aws_ami.ubuntu.root_device_name

    ebs {
      volume_type           = "gp3"
      volume_size           = var.image_builder_root_volume_size
      encrypted             = true
      delete_on_termination = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_imagebuilder_infrastructure_configuration" "api" {
  name                          = "arcamap-api"
  instance_profile_name         = var.image_builder_instance_profile_name
  instance_types                = [var.image_builder_instance_type]
  subnet_id                     = var.api_subnet_id
  security_group_ids            = [var.image_builder_security_group_id]
  terminate_instance_on_failure = true

  instance_metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
}

# 자동 schedule과 Terraform image 리소스를 만들지 않습니다. 이전 빌드 기록은 lifecycle이 관리합니다.
resource "aws_imagebuilder_image_pipeline" "api" {
  name                             = "arcamap-api"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.api.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.api.arn

  image_tests_configuration {
    image_tests_enabled = true
  }

  logging_configuration {
    image_log_group_name    = var.imagebuilder_log_group_name
    pipeline_log_group_name = var.imagebuilder_log_group_name
  }

  lifecycle {
    replace_triggered_by = [aws_imagebuilder_image_recipe.api]
  }
}

resource "aws_iam_role" "lifecycle" {
  name = "arcamap-imagebuilder-lifecycle"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "imagebuilder.amazonaws.com" }
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lifecycle" {
  role       = aws_iam_role.lifecycle.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/EC2ImageBuilderLifecycleExecutionPolicy"
}

resource "aws_imagebuilder_lifecycle_policy" "api" {
  name           = "arcamap-api"
  description    = "생성 후 7일이 지난 미보호 배포 이미지와 AMI·snapshot 정리. AWS Backup 이미지는 선택하지 않습니다."
  execution_role = aws_iam_role.lifecycle.arn
  resource_type  = "AMI_IMAGE"

  policy_detail {
    action {
      type = "DELETE"
      include_resources {
        amis      = true
        snapshots = true
      }
    }

    filter {
      type  = "AGE"
      unit  = "DAYS"
      value = 7
    }

    exclusion_rules {
      tag_map = { ArcaMapProtected = "true" }
    }
  }

  resource_selection {
    recipe {
      name             = "arcamap-api"
      semantic_version = "x.x.x"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lifecycle]
}
