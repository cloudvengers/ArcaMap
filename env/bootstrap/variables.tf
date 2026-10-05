variable "cluster_arn" {
  description = "초기화할 실제 서울 DSQL 클러스터 ARN."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:dsql:ap-northeast-2:565725315772:cluster/[a-z0-9]+$", var.cluster_arn))
    error_message = "실제 대상 계정의 서울 DSQL 클러스터 ARN을 지정해야 합니다."
  }
}

variable "deployment_bucket" {
  description = "API IAM 단계에서 생성한 기존 배포 버킷 이름."
  type        = string
}

variable "bundle_path" {
  description = "기존 CSV·DSQL loader·WAS pyproject/lock만 포함한 bootstrap tar.gz 경로."
  type        = string
}
