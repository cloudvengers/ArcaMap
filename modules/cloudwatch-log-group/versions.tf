terraform {                     # Terraform 버전·공급자 요구 사항
  required_version = "= 1.16.1" # 사용할 Terraform CLI 버전

  required_providers {          # 필요한 공급자 목록
    aws = {                     # AWS 공급자 요구 사항
      source  = "hashicorp/aws" # 공급자의 레지스트리 주소
      version = "= 6.63.0"      # 사용할 AWS 공급자 버전
    }                           # 설정 묶음 끝
  }                             # 설정 묶음 끝
}                               # 설정 묶음 끝
