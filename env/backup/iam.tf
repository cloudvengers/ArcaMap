# AWS Backup 공식 정책에서 DSQL·EC2/EBS·S3 권한만 사용하고 원본/키/PassRole 범위를 제한합니다.
# https://docs.aws.amazon.com/aws-backup/latest/devguide/security-iam-awsmanpol.html
locals {
  shared_statements = [
    {
      Sid      = "DescribeApprovedKeys"
      Effect   = "Allow"
      Action   = "kms:DescribeKey"
      Resource = local.kms_key_arns
    },
    {
      Sid      = "UseApprovedKeys"
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:GenerateDataKeyWithoutPlaintext", "kms:ReEncryptFrom", "kms:ReEncryptTo"]
      Resource = local.kms_key_arns
      Condition = {
        StringEquals = {
          "kms:ViaService" = ["backup.ap-northeast-2.amazonaws.com", "ec2.ap-northeast-2.amazonaws.com", "s3.ap-northeast-2.amazonaws.com", "dsql.ap-northeast-2.amazonaws.com"]
        }
      }
    },
    {
      Sid      = "CreateResourceGrants"
      Effect   = "Allow"
      Action   = "kms:CreateGrant"
      Resource = local.kms_key_arns
      Condition = {
        Bool = {
          "kms:GrantIsForAWSResource" = "true"
        }
      }
    },
    {
      Sid      = "DescribeVault"
      Effect   = "Allow"
      Action   = "backup:DescribeBackupVault"
      Resource = aws_backup_vault.main.arn
    }
  ]
  backup_statements = concat(
    local.shared_statements,
    [
      {
        Sid      = "DSQLBackup"
        Effect   = "Allow"
        Action   = ["dsql:StartBackupJob", "dsql:StopBackupJob", "dsql:GetCluster", "dsql:ListTagsForResource"]
        Resource = var.dsql_cluster_arn
      },
      {
        # 실제 AWS Backup 상태 조회는 같은 계정·리전의 cluster/* 범위를 요청합니다.
        Sid      = "DSQLBackupJobStatus"
        Effect   = "Allow"
        Action   = "dsql:GetBackupJob"
        Resource = local.dsql_restore_arn
      },
      {
        Sid      = "DSQLDiscovery"
        Effect   = "Allow"
        Action   = "dsql:ListClusters"
        Resource = "*"
      },
      {
        Sid      = "GetResourcesPermissions"
        Effect   = "Allow"
        Action   = ["tag:GetResources"]
        Resource = "*"
      },
      {
        Sid      = "CloudWatchGetMetricDataPermissions"
        Effect   = "Allow"
        Action   = "cloudwatch:GetMetricData"
        Resource = "*"
      },
      {
        Sid      = "EventBridgePermissionsForAwsBackupManagedRule"
        Effect   = "Allow"
        Action   = ["events:DeleteRule", "events:PutTargets", "events:DescribeRule", "events:EnableRule", "events:PutRule", "events:RemoveTargets", "events:ListTargetsByRule", "events:DisableRule"]
        Resource = "arn:aws:events:ap-northeast-2:${local.account_id}:rule/AwsBackupManagedRule*"
      },
      {
        Sid      = "EventBridgeListRulesPermissions"
        Effect   = "Allow"
        Action   = "events:ListRules"
        Resource = "*"
      },
      {
        Sid      = "S3BucketPermissions"
        Effect   = "Allow"
        Action   = ["s3:GetBucketTagging", "s3:GetInventoryConfiguration", "s3:ListBucketVersions", "s3:ListBucket", "s3:GetBucketVersioning", "s3:GetBucketLocation", "s3:GetBucketAcl", "s3:PutInventoryConfiguration", "s3:GetBucketNotification", "s3:PutBucketNotification"]
        Resource = local.s3_arns
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = local.account_id
          }
        }
      },
      {
        Sid      = "S3ObjectPermissions"
        Effect   = "Allow"
        Action   = ["s3:GetObjectAcl", "s3:GetObject", "s3:GetObjectVersionTagging", "s3:GetObjectVersionAcl", "s3:GetObjectTagging", "s3:GetObjectVersion"]
        Resource = local.s3_object_arns
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = local.account_id
          }
        }
      },
      {
        Sid      = "S3ListBucketPermissions"
        Effect   = "Allow"
        Action   = "s3:ListAllMyBuckets"
        Resource = "*"
      },
      {
        Sid      = "S3BucketTagReadPermissions"
        Effect   = "Allow"
        Action   = ["s3:ListTagsForResource"]
        Resource = local.s3_arns
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = local.account_id
          }
        }
      },
      {
        Sid      = "TagRecoveryPoints"
        Effect   = "Allow"
        Action   = "backup:TagResource"
        Resource = local.recovery_point_arn
      }
    ],
    [for statement in [
      {
        Sid      = "CreateEC2Image"
        Effect   = "Allow"
        Action   = "ec2:CreateImage"
        Resource = concat(sort(tolist(var.api_instance_arns)), [local.image_arn, local.snapshot_arn])
      },
      {
        Sid      = "DescribeEC2"
        Effect   = "Allow"
        Action   = ["ec2:DescribeSnapshots", "ec2:DescribeTags", "ec2:DescribeImages", "ec2:DescribeInstances", "ec2:DescribeInstanceAttribute", "ec2:DescribeInstanceCreditSpecifications", "ec2:DescribeNetworkInterfaces", "ec2:DescribeElasticGpus", "ec2:DescribeSpotInstanceRequests", "ec2:DescribeSnapshotTierStatus"]
        Resource = "*"
      },
      {
        Sid      = "CreateEBSSnapshot"
        Effect   = "Allow"
        Action   = "ec2:CreateSnapshot"
        Resource = ["${local.ec2_arn_prefix}:volume/*", local.snapshot_arn]
      },
      {
        Sid      = "DescribeEBS"
        Effect   = "Allow"
        Action   = "ec2:DescribeVolumes"
        Resource = "*"
      },
      {
        Sid      = "ManageBackupImages"
        Effect   = "Allow"
        Action   = ["ec2:DeregisterImage", "ec2:ModifyImageAttribute"]
        Resource = local.image_arn
        Condition = {
          Null = {
            "aws:ResourceTag/aws:backup:source-resource" = "false"
          }
        }
      },
      {
        Sid      = "ManageBackupSnapshots"
        Effect   = "Allow"
        Action   = ["ec2:DeleteSnapshot", "ec2:ModifySnapshotAttribute"]
        Resource = local.snapshot_arn
        Condition = {
          Null = {
            "aws:ResourceTag/aws:backup:source-resource" = "false"
          }
        }
      },
      {
        Sid      = "TagEC2Backup"
        Effect   = "Allow"
        Action   = "ec2:CreateTags"
        Resource = [local.image_arn, local.snapshot_arn]
      }
    ] : statement if length(var.api_instance_arns) > 0]
  )
  restore_statements = concat(
    local.shared_statements,
    [
      {
        Sid      = "RestoreDSQL"
        Effect   = "Allow"
        Action   = ["dsql:StartRestoreJob", "dsql:GetRestoreJob", "dsql:StopRestoreJob", "dsql:TagResource", "dsql:CreateCluster", "dsql:UpdateCluster", "dsql:GetCluster"]
        Resource = local.dsql_restore_arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucketVersions", "s3:ListBucket", "s3:GetBucketVersioning", "s3:GetBucketLocation", "s3:PutBucketVersioning", "s3:PutBucketOwnershipControls", "s3:GetBucketOwnershipControls"]
        Resource = local.s3_arns
        Sid      = "RestoreS3Buckets"
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = local.account_id
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:DeleteObject", "s3:PutObjectVersionAcl", "s3:GetObjectVersionAcl", "s3:GetObjectTagging", "s3:PutObjectTagging", "s3:GetObjectAcl", "s3:PutObjectAcl", "s3:ListMultipartUploadParts", "s3:PutObject"]
        Resource = local.s3_object_arns
        Sid      = "RestoreS3Objects"
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = local.account_id
          }
        }
      }
    ],
    [
      {
        Sid      = "EC2DescribePermissions"
        Effect   = "Allow"
        Action   = ["ec2:DescribeImages", "ec2:DescribeInstances", "ec2:DescribeSnapshots", "ec2:DescribeVolumes", "ec2:DescribeAccountAttributes", "ec2:DescribeAddresses", "ec2:DescribeAvailabilityZones", "ec2:DescribeSecurityGroups", "ec2:DescribeSubnets", "ec2:DescribeVpcs", "ec2:DescribeInternetGateways", "ec2:DescribeSnapshotTierStatus", "ec2:DescribeRouteTables"]
        Resource = "*"
      },
      {
        Sid      = "RestoreEBS"
        Effect   = "Allow"
        Action   = ["ec2:CreateVolume", "ec2:DeleteVolume"]
        Resource = [local.snapshot_arn, "${local.ec2_arn_prefix}:volume/*"]
      },
      {
        Sid      = "RunRestoredEC2"
        Effect   = "Allow"
        Action   = "ec2:RunInstances"
        Resource = [local.image_arn, local.snapshot_arn, "${local.ec2_arn_prefix}:instance/*", "${local.ec2_arn_prefix}:volume/*", "${local.ec2_arn_prefix}:network-interface/*", "${local.ec2_arn_prefix}:subnet/*", "${local.ec2_arn_prefix}:security-group/*", "${local.ec2_arn_prefix}:key-pair/*"]
      },
      {
        Sid      = "TerminateRestoredEC2"
        Effect   = "Allow"
        Action   = "ec2:TerminateInstances"
        Resource = "${local.ec2_arn_prefix}:instance/*"
        Condition = {
          Null = {
            "aws:ResourceTag/aws:backup:source-resource" = "false"
          }
        }
      },
      {
        Sid      = "EC2CreateTagsPermissions"
        Effect   = "Allow"
        Action   = ["ec2:CreateTags"]
        Resource = ["${local.ec2_arn_prefix}:instance/*", "${local.ec2_arn_prefix}:volume/*"]
        Condition = {
          StringLike = {
            "ec2:CreateAction" = ["RunInstances", "CreateVolume"]
          }
        }
      },
      {
        Sid      = "PassAPIRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = var.api_restore_role_arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ec2.amazonaws.com"
          }
        }
      }
    ]
  )
}

resource "aws_iam_role" "service" {
  for_each = toset(["backup", "restore"])

  name = "arcamap-backup-${each.key}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "backup.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "service" {
  for_each = aws_iam_role.service

  name = "arcamap-backup-${each.key}"
  role = each.value.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      backup  = local.backup_statements
      restore = local.restore_statements
    }[each.key]
  })
}
