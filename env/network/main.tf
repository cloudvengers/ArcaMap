module "network" {                 # 공통 네트워크 모듈 연결
  source = "../../modules/network" # 로컬 하위 모듈 경로
}                                  # 설정 묶음 끝

module "security" {                 # 통신 보안 그룹 모듈 연결
  source = "../../modules/security" # 로컬 하위 모듈 경로

  vpc_id = module.network.vpc_id # 리소스를 연결할 VPC ID
}                                # 설정 묶음 끝
