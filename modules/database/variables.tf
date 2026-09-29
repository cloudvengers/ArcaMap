variable "database_security_group_id" {         # 입력 변수: network 루트에서 생성한 DB 보안 그룹 ID
  description = "network 루트에서 생성한 DB 보안 그룹 ID." # 입력값의 의미와 사용 범위
  type        = string                          # 입력값의 자료형
  nullable    = false                           # null 입력 허용 여부

  validation {                                                                                    # 입력값 검증 규칙
    condition     = can(regex("^sg-([0-9a-f]{8}|[0-9a-f]{17})$", var.database_security_group_id)) # 허용할 입력값 검증 조건
    error_message = "DB 보안 그룹 ID는 sg- 뒤에 8자리 또는 17자리 16진수를 지정해야 합니다."                             # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                               # 설정 묶음 끝
}                                                                                                 # 설정 묶음 끝

variable "database_subnet_ids" {               # 입력 변수: 서로 다른 AZ에 있는 두 DB 격리 서브넷 ID
  description = "서로 다른 AZ에 있는 두 DB 격리 서브넷 ID." # 입력값의 의미와 사용 범위
  type        = list(string)                   # 입력값의 자료형
  nullable    = false                          # null 입력 허용 여부

  validation {                                                                                                                                                                                                     # 입력값 검증 규칙
    condition     = length(var.database_subnet_ids) == 2 && length(distinct(var.database_subnet_ids)) == 2 && alltrue([for id in var.database_subnet_ids : can(regex("^subnet-([0-9a-f]{8}|[0-9a-f]{17})$", id))]) # 허용할 입력값 검증 조건
    error_message = "DB 서브넷은 서로 다른 유효한 ID 두 개여야 합니다."                                                                                                                                                              # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                                                                                # 설정 묶음 끝
}                                                                                                                                                                                                                  # 설정 묶음 끝

variable "db_allocated_storage" {    # 입력 변수: RDS 초기 저장 용량(GiB)
  description = "RDS 초기 저장 용량(GiB)." # 입력값의 의미와 사용 범위
  type        = number               # 입력값의 자료형
  nullable    = false                # null 입력 허용 여부

  validation {                                                                                                    # 입력값 검증 규칙
    condition     = var.db_allocated_storage >= 20 && floor(var.db_allocated_storage) == var.db_allocated_storage # 허용할 입력값 검증 조건
    error_message = "DB 초기 저장 용량은 20GiB 이상의 정수여야 합니다."                                                            # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                               # 설정 묶음 끝
}                                                                                                                 # 설정 묶음 끝

variable "db_engine_version" {               # 입력 변수: RDS PostgreSQL의 정확한 엔진 버전
  description = "RDS PostgreSQL의 정확한 엔진 버전." # 입력값의 의미와 사용 범위
  type        = string                       # 입력값의 자료형
  nullable    = false                        # null 입력 허용 여부

  validation {                                                                         # 입력값 검증 규칙
    condition     = can(regex("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$", var.db_engine_version)) # 허용할 입력값 검증 조건
    error_message = "PostgreSQL 버전은 18.3처럼 숫자 2~3구간의 고정 버전이어야 합니다."                    # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                    # 설정 묶음 끝
}                                                                                      # 설정 묶음 끝

variable "db_final_snapshot_identifier" {         # 입력 변수: RDS 삭제 전에 생성할 최종 DB 스냅샷의 고유 이름
  description = "RDS 삭제 전에 생성할 최종 DB 스냅샷의 고유 이름." # 입력값의 의미와 사용 범위
  type        = string                            # 입력값의 자료형
  nullable    = false                             # null 입력 허용 여부

  validation {                                                                                                                                                                                                # 입력값 검증 규칙
    condition     = can(regex("^[A-Za-z][A-Za-z0-9-]{0,254}$", var.db_final_snapshot_identifier)) && !strcontains(var.db_final_snapshot_identifier, "--") && !endswith(var.db_final_snapshot_identifier, "-") # 허용할 입력값 검증 조건
    error_message = "최종 스냅샷 이름은 영문자로 시작하는 1~255자의 영숫자·하이픈이며, 연속 하이픈이나 끝 하이픈은 허용하지 않습니다."                                                                                                                      # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                                                                           # 설정 묶음 끝
}                                                                                                                                                                                                             # 설정 묶음 끝

variable "db_instance_class" {             # 입력 변수: RDS PostgreSQL 인스턴스 클래스
  description = "RDS PostgreSQL 인스턴스 클래스." # 입력값의 의미와 사용 범위
  type        = string                     # 입력값의 자료형
  nullable    = false                      # null 입력 허용 여부

  validation {                                                                              # 입력값 검증 규칙
    condition     = can(regex("^db\\.[a-z][a-z0-9-]*\\.[a-z0-9]+$", var.db_instance_class)) # 허용할 입력값 검증 조건
    error_message = "DB 클래스는 공백 없는 db.t3.small 등의 형식이어야 합니다."                               # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                         # 설정 묶음 끝
}                                                                                           # 설정 묶음 끝

variable "db_max_allocated_storage" {         # 입력 변수: RDS 저장 공간 자동 확장 최대 용량(GiB)
  description = "RDS 저장 공간 자동 확장 최대 용량(GiB)." # 입력값의 의미와 사용 범위
  type        = number                        # 입력값의 자료형
  nullable    = false                         # null 입력 허용 여부

  validation {                                                                                                                                     # 입력값 검증 규칙
    condition     = floor(var.db_max_allocated_storage) == var.db_max_allocated_storage && var.db_max_allocated_storage > var.db_allocated_storage # 허용할 입력값 검증 조건
    error_message = "DB 최대 저장 용량은 초기 용량보다 큰 정수여야 합니다."                                                                                             # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                # 설정 묶음 끝
}                                                                                                                                                  # 설정 묶음 끝

variable "db_password" {                                           # 입력 변수: 신규 RDS PostgreSQL 마스터 비밀번호
  description = "신규 RDS PostgreSQL 마스터 비밀번호. password_wo로만 전달합니다." # 입력값의 의미와 사용 범위
  type        = string                                             # 입력값의 자료형
  nullable    = false                                              # null 입력 허용 여부
  sensitive   = true                                               # CLI 출력에서 입력값을 숨기도록 지정
  ephemeral   = true                                               # 입력값을 상태·계획 파일에 저장하지 않도록 지정

  validation {                                                                                                                                                         # 입력값 검증 규칙
    condition     = can(regex("^[ -~]{8,128}$", var.db_password)) && length(regexall("[/@\"]", var.db_password)) == 0 && var.db_password == trimspace(var.db_password) # 허용할 입력값 검증 조건
    error_message = "DB 비밀번호는 8~128자의 출력 가능한 ASCII여야 하며 /, 큰따옴표, @ 및 앞뒤 공백을 허용하지 않습니다."                                                                                # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                                                                                                                    # 설정 묶음 끝
}                                                                                                                                                                      # 설정 묶음 끝

variable "db_username" {                         # 입력 변수: 신규 RDS PostgreSQL의 마스터 사용자 이름
  description = "신규 RDS PostgreSQL의 마스터 사용자 이름." # 입력값의 의미와 사용 범위
  type        = string                           # 입력값의 자료형
  nullable    = false                            # null 입력 허용 여부

  validation {                                                                 # 입력값 검증 규칙
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]{0,15}$", var.db_username)) # 허용할 입력값 검증 조건
    error_message = "DB 사용자 이름은 영문자로 시작하는 1~16자의 영숫자여야 합니다."                   # 검증 조건을 만족하지 않을 때 표시할 오류
  }                                                                            # 설정 묶음 끝
}                                                                              # 설정 묶음 끝
