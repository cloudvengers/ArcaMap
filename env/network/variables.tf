variable "notification_email" {
  description = "사용자가 배포 시 제공하고 구독을 확인할 운영 경보 수신 이메일 주소."
  type        = string
  nullable    = false

  # ponytail: ASCII dot-atom 주소만 허용합니다. 국제화·따옴표 주소가 필요하면 검증을 확장합니다.
  validation {
    condition = (
      length(var.notification_email) <= 254 &&
      length(split("@", var.notification_email)[0]) <= 64 &&
      can(regex("^[A-Za-z0-9!#$%&'*+/=?^_\\x60{|}~-]+(\\.[A-Za-z0-9!#$%&'*+/=?^_\\x60{|}~-]+)*@[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$", var.notification_email))
    )
    error_message = "notification_email은 공백 없는 유효한 이메일 주소여야 합니다(전체 254자, @ 앞 64자 이하)."
  }
}
