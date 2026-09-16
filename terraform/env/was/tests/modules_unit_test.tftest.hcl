mock_provider "aws" {
  override_during = plan

  mock_data "aws_vpc" {
    defaults = { id = "vpc-00000000000000001" }
  }

  override_data {
    target = data.aws_subnet.public["ap-northeast-2a"]
    values = { id = "subnet-00000000000000001" }
  }

  override_data {
    target = data.aws_subnet.public["ap-northeast-2c"]
    values = { id = "subnet-00000000000000002" }
  }

  override_data {
    target = data.aws_subnet.api["ap-northeast-2a"]
    values = { id = "subnet-00000000000000011" }
  }

  override_data {
    target = data.aws_subnet.api["ap-northeast-2c"]
    values = { id = "subnet-00000000000000012" }
  }

  override_data {
    target = data.aws_security_group.alb
    values = { id = "sg-00000000000000001" }
  }

  override_data {
    target = data.aws_security_group.api
    values = { id = "sg-00000000000000002" }
  }

  mock_data "aws_region" {
    defaults = { region = "ap-northeast-2" }
  }

  mock_data "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:ap-northeast-2:123456789012:certificate/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_data "aws_db_instance" {
    defaults = {
      address = "arcamap-test.example.ap-northeast-2.rds.amazonaws.com"
      # 실제 RDS 응답처럼 별도 인스턴스 포트와 엔드포인트 포트를 구분합니다.
      db_instance_port = 0
      port             = 5432
      db_name          = "arcamap"
      master_username  = "testadmin"
    }
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
        amis = [{
          account_id = "123456789012"
          region     = "ap-northeast-2"
          image      = "ami-00000000000000002"
        }]
      }]
    }
  }

  mock_resource "aws_secretsmanager_secret" {
    defaults = {
      arn = "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:arcamap/api/database-ABCDEF"
      id  = "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:arcamap/api/database-ABCDEF"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      id  = "arcamap-deploy-test"
      arn = "arn:aws:s3:::arcamap-deploy-test"
    }
  }

  mock_resource "aws_lb" {
    defaults = {
      arn      = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:loadbalancer/app/arcamap-api/0000000000000001"
      dns_name = "arcamap-test.ap-northeast-2.elb.amazonaws.com"
      zone_id  = "ZALB123456789"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:targetgroup/arcamap-api/0000000000000001"
      arn_suffix = "targetgroup/arcamap-api/0000000000000001"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:ap-northeast-2:123456789012:log-group:/arcamap/test"
    }
  }
}

mock_provider "aws" {
  alias           = "dns"
  override_during = plan
}

variables {
  db_password                         = "test-only-value"
  api_domain_name                     = "api.example.com"
  frontend_domain_name                = "www.example.com"
  asg_cpu_target                      = 50
  asg_health_check_type               = "EC2"
  asg_max_size                        = 4
  cloudwatch_agent_version            = "1.300072.0b1766"
  ec2_instance_profile_name           = "arcamap-api-test"
  ec2_instance_type                   = "t3.small"
  ec2_root_volume_size                = 20
  image_builder_instance_profile_name = "arcamap-imagebuilder-test"
  image_builder_instance_type         = "t3.small"
  image_builder_root_volume_size      = 20
  image_builder_version               = "1.0.0"
  log_retention_days                  = 30
  route53_role_arn                    = "arn:aws:iam::210987654321:role/Route53"
  route53_zone_id                     = "ZDNS123456789"

  # 아래 입력은 compute 모듈을 직접 실행하는 테스트에서 사용합니다.
  cloudwatch_agent_start = "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/arcamap-cloudwatch-agent.json"
  target_group_arn       = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:targetgroup/arcamap-api/0000000000000001"
  image = {
    id               = "ami-00000000000000002"
    root_device_name = "/dev/sda1"
    root_volume_size = 20
  }
}

run "was_wiring" {
  command = plan

  assert {
    condition = (
      aws_iam_instance_profile.ec2["api"].name == var.ec2_instance_profile_name &&
      aws_iam_instance_profile.ec2["image_builder"].name == var.image_builder_instance_profile_name &&
      alltrue([for key, profile in aws_iam_instance_profile.ec2 :
        profile.role == aws_iam_role.ec2[key].name &&
        jsondecode(aws_iam_role.ec2[key].assume_role_policy).Statement == [{
          Effect    = "Allow"
          Action    = "sts:AssumeRole"
          Principal = { Service = "ec2.amazonaws.com" }
        }] &&
        aws_iam_role_policy_attachment.ssm[key].role == profile.role &&
        aws_iam_role_policy_attachment.ssm[key].policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" &&
        aws_iam_role_policy_attachment.cloudwatch[key].role == profile.role &&
        aws_iam_role_policy_attachment.cloudwatch[key].policy_arn == "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      ])
    )
    error_message = "두 프로파일은 각 EC2 역할에 연결되고, EC2만 역할을 수임하며 SSM·CloudWatch 권한을 가져야 합니다."
  }

  assert {
    condition = (
      aws_iam_role_policy_attachment.image_builder.role == aws_iam_role.ec2["image_builder"].name &&
      aws_iam_role_policy_attachment.image_builder.policy_arn == "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder" &&
      aws_iam_role_policy.imagebuilder_log_test.role == aws_iam_role.ec2["image_builder"].name &&
      jsondecode(aws_iam_role_policy.imagebuilder_log_test.policy).Statement == [{
        Effect   = "Allow"
        Action   = "logs:FilterLogEvents"
        Resource = "${module.log_groups["ec2_system"].log_group.arn}:*"
      }]
    )
    error_message = "Image Builder 전용 권한과 시스템 로그 그룹에 한정한 로그 테스트 조회 권한은 빌드 역할에 연결해야 합니다."
  }

  assert {
    condition = (
      data.aws_vpc.main.tags["Name"] == "arcamap-vpc" &&
      data.aws_security_group.alb.name == "arcamap-alb" &&
      data.aws_security_group.api.name == "arcamap-api" &&
      data.aws_security_group.alb.vpc_id == data.aws_vpc.main.id &&
      data.aws_security_group.api.vpc_id == data.aws_vpc.main.id &&
      toset(keys(data.aws_subnet.public)) == toset(["ap-northeast-2a", "ap-northeast-2c"]) &&
      toset(keys(data.aws_subnet.api)) == toset(["ap-northeast-2a", "ap-northeast-2c"]) &&
      alltrue([for az, subnet in data.aws_subnet.public :
        subnet.vpc_id == data.aws_vpc.main.id &&
        subnet.availability_zone == az &&
        subnet.tags["Name"] == "arcamap-public-${az}"
      ]) &&
      alltrue([for az, subnet in data.aws_subnet.api :
        subnet.vpc_id == data.aws_vpc.main.id &&
        subnet.availability_zone == az &&
        subnet.tags["Name"] == "arcamap-api-${az}"
      ])
    )
    error_message = "WAS는 app의 VPC 안에서 ALB·API 보안 그룹과 역할·AZ별 서브넷을 조회해야 합니다."
  }

  assert {
    condition = (
      data.aws_db_instance.postgres.db_instance_identifier == "arcamap-postgres" &&
      output.launch_template.ami_id == output.built_image.id &&
      output.built_image.id == "ami-00000000000000002" &&
      output.autoscaling_group.name == "arcamap-api" &&
      output.api_url == "https://api.example.com" &&
      toset(keys(module.service_alarms)) == toset([
        "asg-inservice", "ec2-status-check", "ec2-cpu", "alb-healthy-hosts", "alb-5xx", "api-5xx"
      ]) &&
      toset(keys(output.log_groups)) == toset(["ec2_system", "api", "alb", "imagebuilder"])
    )
    error_message = "WAS는 빌드한 AMI를 운영 시작 템플릿에 직접 연결하고 기존 ASG·로그·경보 구성을 유지해야 합니다."
  }

  assert {
    condition = alltrue([for policy in aws_iam_role_policy.api_secret :
      jsondecode(policy.policy).Statement == [{
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_secretsmanager_secret.database.arn
      }]
      ]) && jsondecode(aws_iam_role_policy.imagebuilder_artifact.policy).Statement == [{
      Effect   = "Allow"
      Action   = "s3:GetObject"
      Resource = "${module.deployment_bucket.bucket.arn}/${local.api_artifact_key}"
    }]
    error_message = "인증정보와 배포 파일 조회 권한은 해당 Secret과 배포 객체 하나로 제한해야 합니다."
  }

  assert {
    condition = (
      aws_route53_record.api.zone_id == var.route53_zone_id &&
      aws_route53_record.api.name == var.api_domain_name &&
      aws_route53_record.api.type == "A" &&
      !aws_route53_record.api.allow_overwrite &&
      one(aws_route53_record.api.alias).name == "dualstack.${module.alb.alb.dns_name}" &&
      one(aws_route53_record.api.alias).zone_id == module.alb.alb.zone_id &&
      one(aws_route53_record.api.alias).evaluate_target_health
    )
    error_message = "API는 기존 DNS 영역에 다른 계정의 ALB를 가리키는 A 별칭을 생성하고 기존 레코드를 덮어쓰지 않아야 합니다."
  }
}

run "initial_compute" {
  command = plan

  module {
    source = "../../modules/compute"
  }

  variables {
    api_subnet_ids        = ["subnet-00000000000000011", "subnet-00000000000000012"]
    api_security_group_id = "sg-00000000000000002"
  }

  assert {
    condition = (
      length(aws_autoscaling_group.api) == 1 &&
      length(aws_autoscaling_policy.api_cpu) == 1 &&
      aws_autoscaling_group.api[0].min_size == 2 &&
      aws_autoscaling_group.api[0].max_size == 4 &&
      aws_autoscaling_group.api[0].health_check_type == "EC2" &&
      aws_autoscaling_policy.api_cpu[0].autoscaling_group_name == aws_autoscaling_group.api[0].name &&
      aws_autoscaling_policy.api_cpu[0].policy_type == "TargetTrackingScaling" &&
      aws_autoscaling_policy.api_cpu[0].target_tracking_configuration[0].target_value == 50
    )
    error_message = "초기 ASG는 EC2 상태만 검사하며, ASG 1개·최소 2대·CPU 목표 확장 정책을 유지해야 합니다."
  }

  assert {
    condition = (
      strcontains(base64decode(aws_launch_template.api.user_data), var.cloudwatch_agent_start) &&
      !strcontains(base64decode(aws_launch_template.api.user_data), "database.env") &&
      !strcontains(base64decode(aws_launch_template.api.user_data), "PGPASSWORD=") &&
      aws_launch_template.api.metadata_options[0].http_tokens == "required"
    )
    error_message = "user_data는 CloudWatch Agent만 시작하고 중복 RDS 설정이나 비밀번호를 포함하지 않으며 IMDSv2를 강제해야 합니다."
  }
}

run "enable_api_health_checks" {
  command = plan

  module {
    source = "../../modules/compute"
  }

  variables {
    api_subnet_ids        = ["subnet-00000000000000011", "subnet-00000000000000012"]
    api_security_group_id = "sg-00000000000000002"
    asg_health_check_type = "ELB"
  }

  assert {
    condition = (
      aws_autoscaling_group.api[0].health_check_type == "ELB" &&
      one(one(aws_autoscaling_group.api[0].instance_refresh).preferences).min_healthy_percentage == 0 &&
      one(one(aws_autoscaling_group.api[0].instance_refresh).preferences).max_healthy_percentage == 100 &&
      aws_autoscaling_group.api[0].target_group_arns == toset([var.target_group_arn])
    )
    error_message = "API 교체는 ALB 상태 검사를 사용하며 개발 단계에서는 기존 EC2를 유지하기 위한 추가 용량을 만들지 않아야 합니다."
  }
}

run "reject_invalid_health_check_type" {
  command = plan

  variables {
    asg_health_check_type = "HTTP"
  }

  expect_failures = [var.asg_health_check_type]
}

run "reject_duplicate_instance_profiles" {
  command = plan

  variables {
    image_builder_instance_profile_name = "ARCAMAP-API-TEST"
  }

  expect_failures = [var.image_builder_instance_profile_name]
}

run "reject_same_frontend_and_api_domain" {
  command = plan

  variables {
    api_domain_name = "www.example.com"
  }

  expect_failures = [var.api_domain_name]
}

run "reject_volume_smaller_than_image" {
  command = plan

  module {
    source = "../../modules/compute"
  }

  variables {
    api_subnet_ids        = ["subnet-00000000000000011", "subnet-00000000000000012"]
    api_security_group_id = "sg-00000000000000002"
    image = {
      id               = "ami-00000000000000002"
      root_device_name = "/dev/sda1"
      root_volume_size = 30
    }
  }

  expect_failures = [var.ec2_root_volume_size]
}
