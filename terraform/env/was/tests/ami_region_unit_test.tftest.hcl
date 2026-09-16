mock_provider "aws" {
  override_during = plan

  mock_data "aws_region" {
    defaults = { region = "us-west-2" }
  }

  mock_data "aws_ami" {
    defaults = {
      id               = "ami-00000000000000001"
      root_device_name = "/dev/sda1"
    }
  }

  mock_resource "aws_imagebuilder_image" {
    defaults = {
      output_resources = [{
        amis = [
          { account_id = "123456789012", region = "ap-northeast-2", image = "ami-00000000000000002" },
          { account_id = "123456789012", region = "us-west-2", image = "ami-00000000000000003" }
        ]
      }]
    }
  }
}

run "ami_lookup_and_provider_region" {
  command = plan

  module {
    source = "../../modules/image-builder"
  }

  variables {
    api_subnet_id                       = "subnet-00000000000000011"
    api_security_group_id               = "sg-00000000000000002"
    image_builder_instance_profile_name = "arcamap-imagebuilder-test"
    image_builder_instance_type         = "t3.small"
    image_builder_root_volume_size      = 20
    image_builder_version               = "1.0.0"
    cloudwatch_agent_version            = "1.300072.0b1766"
    cloudwatch_agent_config_json        = jsonencode({ logs = { logs_collected = { journald = { collect_list = [] } } } })
    cloudwatch_agent_start              = "systemctl start amazon-cloudwatch-agent"
    system_log_group_name               = "/arcamap/test/system"
    imagebuilder_log_group_name         = "/aws/imagebuilder/arcamap-test"
    api_installation = {
      artifact_uri         = "s3://arcamap-test/was/test.tar.gz"
      artifact_sha256      = sha256("test")
      service_base64       = base64encode("test service")
      secret_loader_base64 = base64encode("test loader")
      rds_ca_base64        = base64encode("test CA")
      secret_arn           = "arn:aws:secretsmanager:us-west-2:123456789012:secret:arcamap/api/database-ABCDEF"
    }
  }

  assert {
    condition = (
      data.aws_ami.ubuntu.most_recent &&
      toset(data.aws_ami.ubuntu.owners) == toset(["099720109477"]) &&
      one([for filter in data.aws_ami.ubuntu.filter : filter.values if filter.name == "name"]) == toset(["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"]) &&
      aws_imagebuilder_image_recipe.api.parent_image == data.aws_ami.ubuntu.id &&
      one(aws_imagebuilder_image_recipe.api.block_device_mapping).device_name == data.aws_ami.ubuntu.root_device_name
    )
    error_message = "Canonical Ubuntu 26.04 최신 AMI 조회 결과와 루트 장치를 이미지 레시피에 연결해야 합니다."
  }

  assert {
    condition = (
      output.image.id == "ami-00000000000000003" &&
      strcontains(aws_imagebuilder_component.test.data, "aws:amz:us-west-2:logs") &&
      strcontains(aws_imagebuilder_component.test.data, "https://logs.us-west-2.amazonaws.com/")
    )
    error_message = "로그 요청의 서명·엔드포인트와 빌드 AMI 선택은 조회한 Provider 리전을 따라야 합니다."
  }
}
