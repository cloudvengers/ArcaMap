variable "dsql_cluster_connection_quota" {
  description = "DSQL 연결 수 경보에 사용할 실제 클러스터 연결 수 한도. 기본 서비스 한도는 10000이며 증액 시 갱신합니다."
  type        = number
  default     = 10000
  nullable    = false

  validation {
    condition     = var.dsql_cluster_connection_quota >= 1 && floor(var.dsql_cluster_connection_quota) == var.dsql_cluster_connection_quota
    error_message = "DSQL 클러스터 연결 수 한도는 양의 정수여야 합니다."
  }
}
