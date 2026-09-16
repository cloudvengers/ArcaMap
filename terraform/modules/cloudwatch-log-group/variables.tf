variable "log_retention_days" {
  description = "CloudWatch와 CloudFront 로그 보존 기간(일)."
  type        = number
  nullable    = false

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "로그 보존 기간은 CloudWatch Logs가 지원하는 양의 보존 일수여야 합니다."
  }
}

variable "name" {
  description = "CloudWatch 로그 그룹의 전체 이름."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9/._#-]{1,512}$", var.name)) && !startswith(var.name, "aws/")
    error_message = "로그 그룹 이름은 1~512자의 영숫자·/._#-로 지정하며 aws/로 시작할 수 없습니다."
  }
}
