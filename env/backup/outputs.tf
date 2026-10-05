output "backup_role_arn" {
  description = "운영자가 StartBackupJob에 전달할 전용 백업 역할 ARN. 백업 작업을 실행하지 않습니다."
  value       = aws_iam_role.service["backup"].arn
}

output "backup_targets" {
  description = "운영자가 온디맨드 백업에 사용할 원본 ARN. EC2 연결 EBS는 포함되며 별도 등록하지 않습니다. 현재 EC2는 변경 직전 다시 확인하세요."
  value = {
    dsql = var.dsql_cluster_arn
    ec2  = var.api_instance_arns
    s3   = var.s3_bucket_arns
  }
}

output "on_demand_lifecycle" {
  description = "StartBackupJob의 Lifecycle.DeleteAfterDays=7 입력 기준입니다. 운영자가 백업 완료 후 변경하고 같은 대상의 이전 recovery point를 정리해야 하며, 실패 시 변경 중단·기존 유지가 필요합니다. IaC가 7일/latest1을 자동 보장하지 않습니다."
  value       = { delete_after_days = 7 }
}

output "restore_role_arn" {
  description = "운영자가 StartRestoreJob에 전달할 전용 복원 역할 ARN. DSQL은 새 클러스터로 복원되므로 DB Endpoint·Private DNS와 API IAM·접속 설정을 바꿔야 합니다."
  value       = aws_iam_role.service["restore"].arn
}

output "vault" {
  description = "서울 공통 백업 볼트와 KMS. EC2/EBS 백업 암호화는 원본 EBS 키를 따릅니다."
  value = {
    name        = aws_backup_vault.main.name
    arn         = aws_backup_vault.main.arn
    kms_key_arn = aws_kms_key.backup.arn
  }
}
