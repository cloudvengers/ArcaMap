data "aws_region" "current" {} # 현재 AWS 리전 조회

data "aws_ami" "ubuntu" {        # 기반 AMI 조회
  most_recent = true             # 조회 결과 중 최신 항목 선택 여부
  owners      = ["099720109477"] # AMI를 게시한 AWS 계정 목록

  filter {                                                                      # 조회 대상 또는 객체 수명 주기 필터
    name   = "name"                                                             # AWS 리소스·규칙·작업 이름
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"] # 조회 필터 값 또는 테스트 대체 값
  }                                                                             # 설정 묶음 끝

  filter {                  # 조회 대상 또는 객체 수명 주기 필터
    name   = "architecture" # AWS 리소스·규칙·작업 이름
    values = ["x86_64"]     # 조회 필터 값 또는 테스트 대체 값
  }                         # 설정 묶음 끝

  filter {                 # 조회 대상 또는 객체 수명 주기 필터
    name   = "state"       # AWS 리소스·규칙·작업 이름
    values = ["available"] # 조회 필터 값 또는 테스트 대체 값
  }                        # 설정 묶음 끝
}                          # 설정 묶음 끝
