# terraform test만 실행합니다. AWS 호출과 실제 이미지 빌드는 수행하지 않습니다.
mock_provider "aws" {
  mock_data "aws_vpc" {
    defaults = { id = "vpc-00000000" }
  }
  mock_data "aws_security_group" {
    defaults = { id = "sg-00000000" }
  }
  mock_data "aws_subnet" {
    defaults = { id = "subnet-00000003", map_public_ip_on_launch = false }
  }
  mock_data "aws_ami" {
    defaults = {
      id               = "ami-00000000"
      root_device_name = "/dev/sda1"
      block_device_mappings = [{
        device_name = "/dev/sda1"
        ebs         = { volume_size = 20, encrypted = true, volume_type = "gp3" }
      }]
    }
  }
  mock_data "aws_region" {
    defaults = { region = "ap-northeast-2" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:ap-northeast-2:123456789012:arcamap-operations" }
  }
  mock_data "aws_imagebuilder_image" {
    defaults = {
      build_version_arn = "arn:aws:imagebuilder:ap-northeast-2:123456789012:image/arcamap-api/2.0.0/1"
      tags = {
        ArcaMapProtected         = "true"
        ArcaMapValidated         = "true"
        ArcaMapEnvironmentSha256 = sha256("AWS_REGION=ap-northeast-2\nPGHOST=mockcluster.dsql-test.ap-northeast-2.on.aws\nDSQL_AUTH_HOST=mockcluster.dsql-test.ap-northeast-2.on.aws\nPGPORT=5432\nPGDATABASE=postgres\nPGUSER=arcamap_api\nPGSSLMODE=verify-full\nPGSSLROOTCERT=/etc/ssl/certs/Amazon_Root_CA_1.pem\n")
      }
      image_tests_configuration = [{ image_tests_enabled = true }]
      output_resources          = [{ amis = [{ region = "ap-northeast-2", image = "ami-00000000" }] }]
    }
  }
  mock_resource "aws_s3_bucket" {
    override_during = plan
    defaults        = { id = "arcamap-deploy-mock", arn = "arn:aws:s3:::arcamap-deploy-mock" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    override_during = plan
    defaults        = { arn = "arn:aws:logs:ap-northeast-2:123456789012:log-group:/arcamap/mock" }
  }
  mock_resource "aws_lb_target_group" {
    override_during = plan
    defaults        = { arn = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:targetgroup/arcamap-api/0123456789abcdef" }
  }
}

mock_provider "aws" {
  alias = "dns"
}

override_data {
  target = data.aws_subnet.public["ap-northeast-2a"]
  values = { id = "subnet-00000001" }
}
override_data {
  target = data.aws_subnet.public["ap-northeast-2c"]
  values = { id = "subnet-00000002" }
}
override_data {
  target = data.aws_security_group.image_builder
  values = { id = "sg-00000001" }
}

variables {
  certificate_arn  = "arn:aws:acm:ap-northeast-2:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  route53_role_arn = "arn:aws:iam::123456789012:role/Route53"
  database = {
    cluster_id  = "mockcluster"
    cluster_arn = "arn:aws:dsql:ap-northeast-2:123456789012:cluster/mockcluster"
    region      = "ap-northeast-2"
    host        = "mockcluster.dsql-test.ap-northeast-2.on.aws"
    auth_host   = "mockcluster.dsql-test.ap-northeast-2.on.aws"
    dbname      = "postgres"
    port        = 5432
  }
}

run "bootstrap_before_database_setup" {
  command = plan

  assert {
    condition     = local.api_service == file("${path.module}/../../app/was/deploy/arcamap-api.service")
    error_message = "이미지에 전달할 systemd 서비스는 앱 배포 파일과 바이트 단위로 일치해야 합니다."
  }
  assert {
    condition     = length(module.compute) == 0 && length(module.image_builder) == 0 && length(aws_s3_object.api) == 0 && length(aws_iam_role_policy.imagebuilder_artifact) == 0
    error_message = "최초 IAM 준비 단계에서는 배포 파일·이미지 빌드·ASG 생성을 요구하면 안 됩니다."
  }
  assert {
    condition     = alltrue([for policy in aws_iam_role_policy.dsql : jsondecode(policy.policy).Statement == [{ Action = "dsql:DbConnect", Effect = "Allow", Resource = var.database.cluster_arn }]])
    error_message = "운영·빌드 role은 대상 클러스터의 DbConnect만 가져야 합니다. admin 또는 wildcard 권한은 금지합니다."
  }
  assert {
    condition     = strcontains(local.api_environment, "PGHOST=${var.database.auth_host}") && strcontains(local.api_environment, "PGDATABASE=postgres") && strcontains(local.api_environment, "PGUSER=arcamap_api") && strcontains(local.api_environment, "PGSSLMODE=verify-full") && strcontains(local.api_environment, "Amazon_Root_CA_1.pem") && !strcontains(local.api_environment, "PGPASSWORD") && !strcontains(local.api_service, "load-environment")
    error_message = "DSQL 환경은 동일한 host·토큰 host와 postgres·verify-full·AmazonRootCA1을 사용하며 비밀번호/Secret 로더를 포함하면 안 됩니다."
  }
  assert {
    condition     = jsondecode(aws_s3_bucket_policy.deployment.policy).Statement[0].Condition.Bool == { "aws:SecureTransport" = "false", "aws:PrincipalIsAWSService" = "false" }
    error_message = "S3 HTTP deny는 일반 주체의 HTTP 요청을 차단하는 두 AND 조건을 유지해야 합니다."
  }
  assert {
    condition = alltrue([for name, alarm in local.service_alarms :
      alarm.threshold == ({ "asg-inservice" = 1, "alb-healthy-hosts" = 1, "ec2-status-check" = 1, "ec2-cpu" = 80, "ec2-memory" = 80, "alb-5xx" = 5, "api-5xx" = 5 })[name] &&
      alarm.statistic == (contains(["asg-inservice", "alb-healthy-hosts"], name) ? "Minimum" : name == "ec2-status-check" ? "Maximum" : contains(["ec2-cpu", "ec2-memory"], name) ? "Average" : "Sum") &&
      alarm.period == (contains(["asg-inservice", "alb-healthy-hosts", "ec2-status-check"], name) ? 60 : 300) &&
      alarm.datapoints_to_alarm == (contains(["asg-inservice", "alb-healthy-hosts", "ec2-status-check"], name) ? 2 : contains(["ec2-cpu", "ec2-memory"], name) ? 3 : 1) &&
      alarm.evaluation_periods == (contains(["alb-5xx", "api-5xx"], name) ? 1 : 3) &&
      alarm.treat_missing_data == (contains(["alb-5xx", "api-5xx"], name) ? "notBreaching" : "missing")
    ])
    error_message = "관측 MADR의 경보 임계값·통계·기간·2/3,3/3,1/1·누락 데이터 기준을 유지해야 합니다."
  }
}

run "deployment_dependencies" {
  command = plan

  variables {
    api_image = "arn:aws:imagebuilder:ap-northeast-2:123456789012:image/arcamap-api/2.0.0/1"
  }
  assert {
    condition     = module.compute[0].autoscaling_group.name == local.service_alarms["asg-inservice"].dimensions.AutoScalingGroupName
    error_message = "경보가 실제 API ASG를 감시하며, 교체 경보와 ASG 사이에 순환 참조가 없어야 합니다."
  }
  assert {
    condition     = module.compute[0].launch_template.ami_id == one(one(data.aws_imagebuilder_image.api[0].output_resources).amis).image
    error_message = "보호된 선택 Image Builder 이미지의 실제 AMI를 운영 시작 템플릿에 연결해야 합니다."
  }
}

run "unprotected_image_is_rejected" {
  command = plan
  variables {
    api_image = "arn:aws:imagebuilder:ap-northeast-2:123456789012:image/arcamap-api/2.0.0/1"
  }
  override_data {
    target = data.aws_imagebuilder_image.api[0]
    values = {
      tags                      = {}
      image_tests_configuration = [{ image_tests_enabled = true }]
      output_resources          = [{ amis = [{ region = "ap-northeast-2", image = "ami-00000000" }] }]
    }
  }
  expect_failures = [data.aws_imagebuilder_image.api]
}

run "different_auth_host_is_rejected" {
  command = plan
  variables {
    database = {
      cluster_id  = "mockcluster"
      cluster_arn = "arn:aws:dsql:ap-northeast-2:123456789012:cluster/mockcluster"
      region      = "ap-northeast-2"
      host        = "mockcluster.dsql-test.ap-northeast-2.on.aws"
      auth_host   = "mockcluster.dsql.ap-northeast-2.on.aws"
      dbname      = "postgres"
      port        = 5432
    }
  }
  expect_failures = [var.database]
}

run "compute_capacity_and_refresh" {
  command = plan
  module {
    source = "../../modules/compute"
  }
  variables {
    api_subnet_ids               = ["subnet-00000003"]
    api_security_group_id        = "sg-00000000"
    image                        = { id = "ami-00000000", root_device_name = "/dev/sda1", root_volume_size = 20 }
    target_group_arn             = "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:targetgroup/arcamap-api/0123456789abcdef"
    ec2_instance_profile_name    = "arcamap-api-instance-profile"
    ec2_instance_type            = "t3.small"
    ec2_root_volume_size         = 20
    asg_max_size                 = 2
    asg_cpu_target               = 50
    asg_memory_target            = 50
    asg_health_check_type        = "ELB"
    asg_name                     = "arcamap-api"
    cloudwatch_agent_start       = "true"
    instance_refresh_alarm_names = ["arcamap-alb-healthy-hosts", "arcamap-alb-5xx", "arcamap-api-5xx"]
  }
  assert {
    condition     = aws_autoscaling_group.api.min_size == 1 && aws_autoscaling_group.api.max_size == 2 && aws_autoscaling_group.api.vpc_zone_identifier == toset(["subnet-00000003"])
    error_message = "ASG는 하나의 사설 서브넷에서 최소1·최대2대로 운영해야 합니다."
  }
  assert {
    condition     = one(aws_launch_template.api.network_interfaces).associate_public_ip_address == "false" && one(one(aws_launch_template.api.block_device_mappings).ebs).encrypted == "true" && one(one(aws_launch_template.api.block_device_mappings).ebs).volume_size == 20 && one(one(aws_launch_template.api.block_device_mappings).ebs).volume_type == "gp3" && aws_launch_template.api.instance_type == "t3.small"
    error_message = "API는 공인 IP 없이 t3.small·암호화 gp3 20GiB를 사용해야 합니다."
  }
  assert {
    condition     = one(aws_autoscaling_policy.api_cpu.target_tracking_configuration).target_value == 50 && !one(aws_autoscaling_policy.api_cpu.target_tracking_configuration).disable_scale_in && one(aws_autoscaling_policy.api_memory.target_tracking_configuration).target_value == 50 && !one(aws_autoscaling_policy.api_memory.target_tracking_configuration).disable_scale_in
    error_message = "CPU·메모리 50% 목표와 두 정책의 축소 허용을 유지해야 합니다."
  }
  assert {
    condition     = one(one(aws_autoscaling_group.api.instance_refresh).preferences).min_healthy_percentage == 100 && one(one(aws_autoscaling_group.api.instance_refresh).preferences).max_healthy_percentage == 200 && one(one(aws_autoscaling_group.api.instance_refresh).preferences).auto_rollback && one(one(one(aws_autoscaling_group.api.instance_refresh).preferences).alarm_specification).alarms == var.instance_refresh_alarm_names
    error_message = "Instance Refresh 100/200과 기존 세 경보의 자동 롤백을 유지해야 합니다."
  }
}

run "image_lifecycle_and_dsql_contract" {
  command = plan
  module {
    source = "../../modules/image-builder"
  }
  variables {
    api_subnet_id                       = "subnet-00000003"
    image_builder_security_group_id     = "sg-00000001"
    image_builder_instance_profile_name = "arcamap-imagebuilder-instance-profile"
    image_builder_instance_type         = "t3.small"
    image_builder_root_volume_size      = 20
    image_builder_version               = "2.0.0"
    cloudwatch_agent_version            = "1.300072.0b1766"
    cloudwatch_agent_config_json        = "{\"logs\":{\"logs_collected\":{\"journald\":{\"collect_list\":[]}}}}"
    cloudwatch_agent_start              = "true"
    system_log_group_name               = "/arcamap/ec2/system"
    imagebuilder_log_group_name         = "/aws/imagebuilder/arcamap-api"
    api_installation = {
      artifact_uri       = "s3://arcamap-deploy-mock/was/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.tar.gz"
      artifact_sha256    = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      service_base64     = "c2VydmljZQ=="
      environment_base64 = "ZW52aXJvbm1lbnQ="
      db_test_user       = "arcamap_imagebuilder"
    }
  }
  assert {
    condition     = one(one(aws_imagebuilder_lifecycle_policy.api.policy_detail).action).type == "DELETE" && one(one(aws_imagebuilder_lifecycle_policy.api.policy_detail).filter).type == "AGE" && one(one(aws_imagebuilder_lifecycle_policy.api.policy_detail).filter).unit == "DAYS" && one(one(aws_imagebuilder_lifecycle_policy.api.policy_detail).filter).value == 7 && one(one(one(aws_imagebuilder_lifecycle_policy.api.policy_detail).action).include_resources).amis && one(one(one(aws_imagebuilder_lifecycle_policy.api.policy_detail).action).include_resources).snapshots
    error_message = "7일 AGE DELETE는 Image Builder 기록과 출력 AMI·스냅샷을 모두 정리해야 합니다."
  }
  assert {
    condition     = one(one(aws_imagebuilder_lifecycle_policy.api.policy_detail).exclusion_rules).tag_map == tomap({ ArcaMapProtected = "true" }) && one(one(aws_imagebuilder_lifecycle_policy.api.resource_selection).recipe).name == "arcamap-api" && one(one(aws_imagebuilder_lifecycle_policy.api.resource_selection).recipe).semantic_version == "x.x.x" && length(aws_imagebuilder_image_pipeline.api.schedule) == 0
    error_message = "이 서비스의 모든 recipe 버전만 선택하고 image 보호태그를 평가하며 자동 빌드 schedule은 만들지 않아야 합니다."
  }
  assert {
    condition     = aws_imagebuilder_infrastructure_configuration.api.security_group_ids == toset(["sg-00000001"]) && aws_imagebuilder_infrastructure_configuration.api.subnet_id == "subnet-00000003"
    error_message = "빌드 EC2에는 같은 API 사설 서브넷과 전용 SG를 연결해야 합니다."
  }
  assert {
    condition     = strcontains(aws_imagebuilder_component.fastapi.data, "uv sync --locked") && strcontains(aws_imagebuilder_component.fastapi.data, "sha256sum --check") && strcontains(aws_imagebuilder_component.fastapi.data, "aurora_dsql_psycopg") && strcontains(aws_imagebuilder_component.fastapi.data, "Amazon_Root_CA_1.pem") && !strcontains(aws_imagebuilder_component.fastapi.data, "secret_loader") && strcontains(aws_imagebuilder_component.fastapi_test.data, "PGUSER=arcamap_imagebuilder") && strcontains(aws_imagebuilder_component.fastapi_test.data, "127.0.0.1:8080/health/db") && !strcontains(aws_imagebuilder_component.fastapi_test.data, "RDS")
    error_message = "기존 패키지 설치·무결성 검사와 DSQL Connector·CA·빌드 역할의 루프백 DB 검사를 유지해야 합니다."
  }
}

run "database_ready_manual_pipeline" {
  command = plan
  variables {
    enable_image_builder = true
    api_artifact_path    = "tests/dependencies_unit_test.tftest.hcl"
  }
  assert {
    condition     = length(module.image_builder) == 1 && length(aws_s3_object.api) == 1 && length(module.compute) == 0
    error_message = "DB 초기화 후에는 수동 pipeline만 준비하고 검증된 image 선택 전 ASG를 생성하면 안 됩니다."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.imagebuilder_artifact[0].policy).Statement[0].Resource == "${module.deployment_bucket.bucket.arn}/${aws_s3_object.api[0].key}" && module.image_builder[0].pipeline.build_tags.ArcaMapEnvironmentSha256 == sha256(local.api_environment)
    error_message = "빌드는 지정 객체 하나만 읽고 현재 DSQL 환경의 SHA256 태그를 시작 요청에 전달해야 합니다."
  }
}

run "unvalidated_image_is_rejected" {
  command = plan
  variables {
    api_image = "arn:aws:imagebuilder:ap-northeast-2:123456789012:image/arcamap-api/2.0.0/1"
  }
  override_data {
    target = data.aws_imagebuilder_image.api[0]
    values = {
      tags                      = { ArcaMapProtected = "true" }
      image_tests_configuration = [{ image_tests_enabled = true }]
      output_resources          = [{ amis = [{ region = "ap-northeast-2", image = "ami-00000000" }] }]
    }
  }
  expect_failures = [data.aws_imagebuilder_image.api]
}
