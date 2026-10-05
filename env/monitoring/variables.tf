variable "dsql_cluster_identifier" {
  description = "env/database의 database.cluster_id 출력. 복구 후 새 클러스터 ID로 변경합니다."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.dsql_cluster_identifier))
    error_message = "DSQL 클러스터 ID는 ARN이나 엔드포인트가 아닌 영문 소문자·숫자 식별자여야 합니다."
  }
}
