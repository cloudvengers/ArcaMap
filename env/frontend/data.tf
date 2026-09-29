data "aws_caller_identity" "current" {} # 현재 AWS 계정 조회

data "aws_s3_bucket" "maps" {                         # S3 버킷 조회
  bucket = "protomaps-565725315772-ap-northeast-2-an" # 대상 S3 버킷 이름 또는 ID
}                                                     # 설정 묶음 끝

data "aws_acm_certificate" "site" {      # ACM 인증서 조회
  region      = "us-east-1"              # 리소스 생성·조회 또는 지표 표시 리전
  domain      = var.frontend_domain_name # EIP 또는 조회 대상의 도메인 지정
  statuses    = ["ISSUED"]               # 조회할 ACM 인증서 상태
  most_recent = false                    # 조회 결과 중 최신 항목 선택 여부
}                                        # 설정 묶음 끝
