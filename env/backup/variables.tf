variable "api_instance_arns" {
  description = "변경 직전 확인한 현재 운영 API EC2 ARN. 최초 배포는 빈 집합이며, 연결 EBS는 EC2 백업에 포함합니다."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for arn in var.api_instance_arns :
      can(regex("^arn:aws:ec2:ap-northeast-2:${data.aws_caller_identity.current.account_id}:instance/i-([0-9a-f]{8}|[0-9a-f]{17})$", arn))
    ])
    error_message = "운영 EC2만 같은 계정·서울 리전의 instance ARN으로 입력하세요. EBS·AMI·ASG ARN은 백업 대상이 아닙니다."
  }
}

variable "api_restore_role_arn" {
  description = "API 출력 ec2_api_role_arn. 복원 EC2의 기존 인스턴스 프로파일 역할에만 PassRole을 허용합니다."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/[A-Za-z0-9_+=,.@/-]+$", var.api_restore_role_arn))
    error_message = "복원 역할은 같은 계정의 API EC2 IAM 역할 ARN이어야 합니다. 인스턴스 프로파일 ARN은 사용할 수 없습니다."
  }
}

variable "dsql_cluster_arn" {
  description = "DB 출력 database.cluster_arn. 백업·복원 단위는 서울의 단일 리전 DSQL 클러스터 전체입니다."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws:dsql:ap-northeast-2:${data.aws_caller_identity.current.account_id}:cluster/[A-Za-z0-9-]+$", var.dsql_cluster_arn))
    error_message = "같은 계정·서울 리전의 DSQL cluster ARN을 입력하세요. 테이블·RDS ARN은 사용할 수 없습니다."
  }
}

variable "existing_backup_management_preferences" {
  description = "적용 직전 서울 DescribeRegionSettings에서 확인한 전체 ResourceTypeManagementPreference. 서비스별 기존 값을 변경하거나 항목을 추가하지 않고 보존합니다."
  type        = map(bool)
  nullable    = false

  validation {
    condition     = length(var.existing_backup_management_preferences) > 0
    error_message = "조회한 전체 management map을 명시하세요. 빈 map으로 기존 계정 설정을 대체할 수 없습니다."
  }
}

variable "existing_backup_opt_in_preferences" {
  description = "적용 직전 서울 DescribeRegionSettings에서 확인한 전체 ResourceTypeOptInPreference. 기존 서비스 값을 보존하고 DSQL만 활성화합니다."
  type        = map(bool)
  nullable    = false

  validation {
    condition     = length(var.existing_backup_opt_in_preferences) > 0
    error_message = "조회한 전체 opt-in map을 명시하세요. 빈 map으로 기존 계정 설정을 대체할 수 없습니다."
  }
}

variable "s3_bucket_arns" {
  description = "서울 S3 5종 ARN. frontend static/photos/maps/cloudfront_logs를 web/photo/maps/logs에, API deployment_bucket.arn을 deploy에 매핑합니다. 버전 관리는 소스 담당 범위입니다."
  type = object({
    web    = string
    photo  = string
    maps   = string
    logs   = string
    deploy = string
  })
  nullable = false

  validation {
    condition = length(toset(values(var.s3_bucket_arns))) == 5 && alltrue([
      for arn in values(var.s3_bucket_arns) :
      can(regex("^arn:aws:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", arn))
    ])
    error_message = "web/photo/maps/logs/deploy에 서로 다른 일반 S3 bucket ARN 5개를 입력하세요. 객체 경로·와일드카드는 허용하지 않습니다."
  }
}

variable "source_kms_key_arns" {
  description = "원본 EBS와 SSE-KMS S3·DSQL 및 복원 대상에 사용하는 실제 서울 KMS key ARN 전체. API EC2가 있으면 원본 EBS 키를 확인해 반드시 포함하세요."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition = (length(var.api_instance_arns) == 0 || length(var.source_kms_key_arns) > 0) && alltrue([
      for arn in var.source_kms_key_arns :
      can(regex("^arn:aws:kms:ap-northeast-2:${data.aws_caller_identity.current.account_id}:key/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|mrk-[0-9a-f]{32})$", arn))
    ])
    error_message = "같은 계정·서울의 실제 key ARN을 입력하세요. 운영 EC2가 있으면 암호화된 원본 EBS의 KMS 키 입력을 생략할 수 없습니다."
  }
}
