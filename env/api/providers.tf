provider "aws" {            # AWS API를 사용할 공급자 구성
  region = "ap-northeast-2" # 리소스 생성·조회 또는 지표 표시 리전
}                           # 설정 묶음 끝

provider "aws" {            # AWS API를 사용할 공급자 구성
  alias  = "dns"            # 공급자 별칭
  region = "ap-northeast-2" # 리소스 생성·조회 또는 지표 표시 리전

  assume_role {                     # DNS 관리 역할 전환 설정
    role_arn = var.route53_role_arn # DNS 관리를 위해 맡을 기존 IAM 역할 ARN
  }                                 # 설정 묶음 끝
}                                   # 설정 묶음 끝
