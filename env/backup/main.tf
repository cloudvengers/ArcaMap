data "aws_caller_identity" "current" {}

locals {
  account_id         = data.aws_caller_identity.current.account_id
  vault_name         = "arcamap-backup"
  vault_arn          = "arn:aws:backup:ap-northeast-2:${local.account_id}:backup-vault:${local.vault_name}"
  ec2_arn_prefix     = "arn:aws:ec2:ap-northeast-2:${local.account_id}"
  dsql_restore_arn   = "arn:aws:dsql:ap-northeast-2:${local.account_id}:cluster/*"
  s3_arns            = values(var.s3_bucket_arns)
  s3_object_arns     = [for arn in local.s3_arns : "${arn}/*"]
  kms_key_arns       = setunion(var.source_kms_key_arns, toset([aws_kms_key.backup.arn]))
  snapshot_arn       = "arn:aws:ec2:ap-northeast-2::snapshot/*"
  image_arn          = "arn:aws:ec2:ap-northeast-2::image/*"
  recovery_point_arn = "arn:aws:backup:ap-northeast-2:${local.account_id}:recovery-point:*"
}

resource "aws_kms_key" "backup" {
  description             = "ArcaMap 서울 공통 AWS Backup 볼트 암호화"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableAccountIAMPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "DenyBackupStorageOutsideAccount"
        Effect    = "Deny"
        Principal = { Service = "backup-storage.amazonaws.com" }
        Action    = ["kms:Decrypt", "kms:RetireGrant", "kms:GenerateDataKey"]
        Resource  = "*"
        Condition = { StringNotEquals = { "aws:SourceAccount" = local.account_id } }
      },
      {
        Sid       = "DenyBackupStorageOutsideVault"
        Effect    = "Deny"
        Principal = { Service = "backup-storage.amazonaws.com" }
        Action    = ["kms:Decrypt", "kms:RetireGrant", "kms:GenerateDataKey"]
        Resource  = "*"
        Condition = { ArnNotEquals = { "aws:SourceArn" = local.vault_arn } }
      }
    ]
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_backup_vault" "main" {
  name          = local.vault_name
  kms_key_arn   = aws_kms_key.backup.arn
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

# DSQL opt-in만 활성화하고 전체 기존 management 설정은 그대로 보존합니다.
resource "aws_backup_region_settings" "main" {
  resource_type_opt_in_preference     = merge(var.existing_backup_opt_in_preferences, { DSQL = true })
  resource_type_management_preference = var.existing_backup_management_preferences
}
