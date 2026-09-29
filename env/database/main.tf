module "database" {                 # RDS 데이터베이스 모듈 연결
  source = "../../modules/database" # 로컬 하위 모듈 경로

  database_subnet_ids          = [for subnet in data.aws_subnet.database : subnet.id] # RDS를 배치할 DB 서브넷 ID 목록
  database_security_group_id   = data.aws_security_group.database.id                  # RDS에 연결할 보안 그룹 ID
  db_allocated_storage         = var.db_allocated_storage                             # RDS 초기 저장 용량(GiB)
  db_engine_version            = var.db_engine_version                                # PostgreSQL 엔진 버전
  db_final_snapshot_identifier = var.db_final_snapshot_identifier                     # 삭제 전 최종 스냅샷 이름
  db_instance_class            = var.db_instance_class                                # RDS 인스턴스 유형
  db_max_allocated_storage     = var.db_max_allocated_storage                         # RDS 자동 확장 최대 저장 용량(GiB)
  db_password                  = var.db_password                                      # RDS 비밀번호 입력
  db_username                  = var.db_username                                      # RDS 관리자 사용자 이름

  # RDS의 자동 로그 내보내기보다 지정한 보존 기간의 로그 그룹을 먼저 생성합니다.
  depends_on = [module.log_groups] # 참조만으로 표현되지 않는 선행 작업 지정
}                                  # 설정 묶음 끝
