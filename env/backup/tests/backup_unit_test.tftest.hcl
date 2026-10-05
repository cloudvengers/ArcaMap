# 모의 공급자와 plan만 사용합니다. 실제 AWS 백업·복원·설정 변경은 실행하지 않습니다.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }

  mock_resource "aws_kms_key" {
    override_during = plan
    defaults        = { arn = "arn:aws:kms:ap-northeast-2:123456789012:key/00000000-0000-0000-0000-000000000001" }
  }

  mock_resource "aws_backup_vault" {
    override_during = plan
    defaults        = { arn = "arn:aws:backup:ap-northeast-2:123456789012:backup-vault:arcamap-backup" }
  }
}

variables {
  api_instance_arns    = []
  source_kms_key_arns  = []
  api_restore_role_arn = "arn:aws:iam::123456789012:role/arcamap-api-ec2"
  dsql_cluster_arn     = "arn:aws:dsql:ap-northeast-2:123456789012:cluster/testcluster"
  existing_backup_opt_in_preferences = {
    DSQL = false
    S3   = false
    EC2  = true
    RDS  = false
  }
  existing_backup_management_preferences = {
    DynamoDB = false
    EFS      = true
  }
  s3_bucket_arns = {
    web    = "arn:aws:s3:::arcamap-test-web"
    photo  = "arn:aws:s3:::arcamap-test-photo"
    maps   = "arn:aws:s3:::arcamap-test-maps"
    logs   = "arn:aws:s3:::arcamap-test-logs"
    deploy = "arn:aws:s3:::arcamap-test-deploy"
  }
}

run "initial_deployment" {
  command = plan

  assert {
    condition = alltrue([
      for filename in fileset(path.module, "*.tf") :
      length(regexall("resource\\s+\"aws_(backup_plan|backup_selection|backup_restore_testing_plan|backup_vault_lock_configuration|lambda_function|scheduler_schedule|cloudwatch_event_rule|s3_bucket|dsql_cluster|instance|ebs_volume)\"", file("${path.module}/${filename}"))) == 0
    ])
    error_message = "온디맨드 전용 루트는 자동 계획·정리·Vault Lock·원본 리소스를 생성할 수 없습니다."
  }

  assert {
    condition     = aws_backup_vault.main.kms_key_arn == aws_kms_key.backup.arn && aws_kms_key.backup.enable_key_rotation && !aws_backup_vault.main.force_destroy
    error_message = "공통 볼트는 회전하는 KMS 키를 사용하며 recovery point를 강제 삭제할 수 없습니다."
  }

  assert {
    condition = alltrue([
      for kind, role in aws_iam_role.service :
      jsondecode(role.assume_role_policy).Statement[0].Principal.Service == "backup.amazonaws.com"
    ])
    error_message = "전용 백업·복원 역할은 AWS Backup만 맡을 수 있어야 합니다."
  }

  assert {
    condition     = aws_backup_region_settings.main.resource_type_opt_in_preference["DSQL"] && !aws_backup_region_settings.main.resource_type_opt_in_preference["S3"] && aws_backup_region_settings.main.resource_type_opt_in_preference["EC2"] && !aws_backup_region_settings.main.resource_type_opt_in_preference["RDS"] && aws_backup_region_settings.main.resource_type_management_preference == var.existing_backup_management_preferences && !contains(keys(aws_backup_region_settings.main.resource_type_management_preference), "DSQL")
    error_message = "DSQL opt-in만 활성화하고 전체 기존 management와 나머지 서비스 opt-in을 유지해야 합니다."
  }

  assert {
    condition     = length(output.backup_targets.ec2) == 0 && length(output.backup_targets.s3) == 5 && output.backup_targets.dsql == var.dsql_cluster_arn && output.on_demand_lifecycle.delete_after_days == 7
    error_message = "최초 배포는 운영 EC2가 없고 DSQL 전체·S3 5종만 출력하며 온디맨드 보존 입력 기준은 7일이어야 합니다."
  }

  assert {
    condition     = !contains([for statement in local.backup_statements : statement.Sid], "CreateEC2Image") && alltrue([for statement in local.shared_statements : statement.Sid == "CreateResourceGrants" ? statement.Condition.Bool["kms:GrantIsForAWSResource"] == "true" : true])
    error_message = "최초 배포에 없는 EC2 백업 권한을 만들지 않으며 KMS grant는 AWS 리소스용으로 제한해야 합니다."
  }

  assert {
    condition     = jsondecode(aws_kms_key.backup.policy).Statement[1].Condition.StringNotEquals["aws:SourceAccount"] == "123456789012" && jsondecode(aws_kms_key.backup.policy).Statement[2].Condition.ArnNotEquals["aws:SourceArn"] == aws_backup_vault.main.arn
    error_message = "Backup storage의 KMS 사용은 같은 계정의 공통 볼트로 제한해야 합니다."
  }
}

run "operational_change" {
  command = plan

  variables {
    api_instance_arns   = ["arn:aws:ec2:ap-northeast-2:123456789012:instance/i-0123456789abcdef0"]
    source_kms_key_arns = ["arn:aws:kms:ap-northeast-2:123456789012:key/00000000-0000-0000-0000-000000000002"]
  }

  assert {
    condition     = length(output.backup_targets.ec2) == 1 && contains([for statement in local.backup_statements : statement.Sid], "CreateEC2Image") && length(local.kms_key_arns) == 2
    error_message = "운영 변경 대상은 현재 EC2와 연결 EBS를 한 번 백업하며 원본 EBS 키와 볼트 키의 권한이 필요합니다."
  }

  assert {
    condition     = contains([for statement in jsondecode(aws_iam_role_policy.service["backup"].policy).Statement : statement.Sid], "DSQLBackup") && !contains([for statement in jsondecode(aws_iam_role_policy.service["backup"].policy).Statement : statement.Sid], "RestoreDSQL") && contains([for statement in jsondecode(aws_iam_role_policy.service["restore"].policy).Statement : statement.Sid], "RestoreDSQL") && !contains([for statement in jsondecode(aws_iam_role_policy.service["restore"].policy).Statement : statement.Sid], "DSQLBackup")
    error_message = "백업·복원 역할에는 각각의 DSQL 정책이 존재해야 하며 서로 바뀌면 안 됩니다."
  }

  assert {
    condition     = alltrue([for statement in jsondecode(aws_iam_role_policy.service["backup"].policy).Statement : statement.Sid == "DSQLBackup" ? statement.Resource == var.dsql_cluster_arn : true]) && alltrue([for statement in jsondecode(aws_iam_role_policy.service["restore"].policy).Statement : statement.Sid == "PassAPIRole" ? statement.Resource == var.api_restore_role_arn && statement.Condition.StringEquals["iam:PassedToService"] == "ec2.amazonaws.com" : true])
    error_message = "DSQL 백업은 원본 ARN에, 복원 PassRole은 API 역할과 EC2 서비스에 한정해야 합니다."
  }

  assert {
    condition     = one([for statement in local.backup_statements : statement if statement.Sid == "DSQLBackupJobStatus"]).Action == "dsql:GetBackupJob" && one([for statement in local.backup_statements : statement if statement.Sid == "DSQLBackupJobStatus"]).Resource == "arn:aws:dsql:ap-northeast-2:123456789012:cluster/*" && !contains(one([for statement in local.backup_statements : statement if statement.Sid == "DSQLBackup"]).Action, "dsql:GetBackupJob")
    error_message = "DSQL 상태 조회만 같은 계정·리전의 cluster/*를 허용하고 원본 작업 권한과 분리해야 합니다."
  }

  assert {
    condition     = alltrue([for statement in jsondecode(aws_iam_role_policy.service["backup"].policy).Statement : statement.Sid == "S3BucketPermissions" ? toset(statement.Resource) == toset(values(var.s3_bucket_arns)) : true]) && alltrue([for statement in jsondecode(aws_iam_role_policy.service["restore"].policy).Statement : statement.Sid == "RestoreS3Objects" ? toset(statement.Resource) == toset([for arn in values(var.s3_bucket_arns) : "${arn}/*"]) : true])
    error_message = "S3 백업·복원 권한은 계약된 5종 버킷과 해당 객체에 한정해야 합니다."
  }
}

run "reject_duplicate_ebs_backup" {
  command = plan

  variables {
    api_instance_arns   = ["arn:aws:ec2:ap-northeast-2:123456789012:volume/vol-0123456789abcdef0"]
    source_kms_key_arns = ["arn:aws:kms:ap-northeast-2:123456789012:key/00000000-0000-0000-0000-000000000002"]
  }

  expect_failures = [var.api_instance_arns]
}

run "reject_missing_ebs_key" {
  command = plan

  variables {
    api_instance_arns = ["arn:aws:ec2:ap-northeast-2:123456789012:instance/i-0123456789abcdef0"]
  }

  expect_failures = [var.source_kms_key_arns]
}

run "reject_empty_account_preferences" {
  command = plan

  variables {
    existing_backup_opt_in_preferences     = {}
    existing_backup_management_preferences = {}
  }

  expect_failures = [var.existing_backup_opt_in_preferences, var.existing_backup_management_preferences]
}
