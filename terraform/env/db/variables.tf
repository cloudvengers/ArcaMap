variable "db_allocated_storage" {
  description = "RDS 초기 저장 용량(GiB)."
  type        = number
  nullable    = false

  validation {
    condition     = var.db_allocated_storage >= 20 && floor(var.db_allocated_storage) == var.db_allocated_storage
    error_message = "DB 초기 저장 용량은 20GiB 이상의 정수여야 합니다."
  }
}

variable "db_engine_version" {
  description = "RDS PostgreSQL의 정확한 엔진 버전."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$", var.db_engine_version))
    error_message = "PostgreSQL 버전은 18.3처럼 숫자 2~3구간의 고정 버전이어야 합니다."
  }
}

variable "db_final_snapshot_identifier" {
  description = "RDS 삭제 전에 생성할 최종 DB 스냅샷의 고유 이름."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9-]{0,254}$", var.db_final_snapshot_identifier)) && !strcontains(var.db_final_snapshot_identifier, "--") && !endswith(var.db_final_snapshot_identifier, "-")
    error_message = "최종 스냅샷 이름은 영문자로 시작하는 1~255자의 영숫자·하이픈이며, 연속 하이픈이나 끝 하이픈은 허용하지 않습니다."
  }
}

variable "db_instance_class" {
  description = "RDS PostgreSQL 인스턴스 클래스."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^db\\.[a-z][a-z0-9-]*\\.[a-z0-9]+$", var.db_instance_class))
    error_message = "DB 클래스는 공백 없는 db.t3.small 등의 형식이어야 합니다."
  }
}

variable "db_max_allocated_storage" {
  description = "RDS 저장 공간 자동 확장 최대 용량(GiB)."
  type        = number
  nullable    = false

  validation {
    condition     = floor(var.db_max_allocated_storage) == var.db_max_allocated_storage && var.db_max_allocated_storage > var.db_allocated_storage
    error_message = "DB 최대 저장 용량은 초기 용량보다 큰 정수여야 합니다."
  }
}

variable "db_max_connections" {
  description = "RDS 생성 후 SHOW max_connections;로 조회한 실제 최대 연결 수. null이면 연결 수 경보 생성을 보류합니다."
  type        = number
  default     = null
  nullable    = true

  validation {
    condition     = var.db_max_connections == null ? true : var.db_max_connections >= 1 && floor(var.db_max_connections) == var.db_max_connections
    error_message = "DB 최대 연결 수는 실제 SHOW max_connections; 결과인 양의 정수여야 합니다."
  }
}

variable "db_password" {
  description = "신규 RDS PostgreSQL 마스터 비밀번호. password_wo로만 전달합니다."
  type        = string
  nullable    = false
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = can(regex("^[ -~]{8,128}$", var.db_password)) && length(regexall("[/@\"]", var.db_password)) == 0 && var.db_password == trimspace(var.db_password)
    error_message = "DB 비밀번호는 8~128자의 출력 가능한 ASCII여야 하며 /, 큰따옴표, @ 및 앞뒤 공백을 허용하지 않습니다."
  }
}

variable "db_username" {
  description = "신규 RDS PostgreSQL의 마스터 사용자 이름."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]{0,15}$", var.db_username))
    error_message = "DB 사용자 이름은 영문자로 시작하는 1~16자의 영숫자여야 합니다."
  }
}

variable "log_retention_days" {
  description = "CloudWatch와 CloudFront 로그 보존 기간(일)."
  type        = number
  nullable    = false

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "로그 보존 기간은 CloudWatch Logs가 지원하는 양의 보존 일수여야 합니다."
  }
}
