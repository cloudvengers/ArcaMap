resource "aws_db_subnet_group" "database" { # RDS 서브넷 그룹 정의
  name       = "arcamap-database"           # AWS 리소스·규칙·작업 이름
  subnet_ids = var.database_subnet_ids      # 리소스를 배치할 서브넷 ID 목록
}                                           # 설정 묶음 끝

resource "aws_db_instance" "postgres" {       # RDS PostgreSQL 인스턴스 정의
  identifier          = "arcamap-postgres"    # RDS 인스턴스 식별자
  db_name             = "arcamap"             # PostgreSQL 데이터베이스 이름
  engine              = "postgres"            # RDS 데이터베이스 엔진
  engine_version      = var.db_engine_version # PostgreSQL 엔진 버전
  instance_class      = var.db_instance_class # RDS 인스턴스 유형
  username            = var.db_username       # RDS 관리자 사용자 이름
  password_wo         = var.db_password       # 상태·계획에 저장하지 않는 DB 비밀번호 입력
  password_wo_version = 1                     # DB 비밀번호 쓰기 변경을 알리는 버전

  multi_az               = true                              # RDS 다중 가용 영역 구성 여부
  db_subnet_group_name   = aws_db_subnet_group.database.name # RDS가 사용할 서브넷 그룹 이름
  vpc_security_group_ids = [var.database_security_group_id]  # EC2·RDS에 연결할 보안 그룹 ID 목록
  publicly_accessible    = false                             # RDS 공인 네트워크 접근 허용 여부
  network_type           = "IPV4"                            # RDS 네트워크 IP 유형
  port                   = 5432                              # 연결을 받을 포트

  storage_type          = "gp3"                        # RDS 저장 장치 유형
  allocated_storage     = var.db_allocated_storage     # RDS 초기 저장 용량(GiB)
  max_allocated_storage = var.db_max_allocated_storage # RDS 저장 공간 자동 확장 상한(GiB)
  storage_encrypted     = true                         # RDS 저장 공간 암호화 여부

  auto_minor_version_upgrade  = false                            # DB 부 버전 자동 업그레이드 여부
  allow_major_version_upgrade = false                            # DB 주 버전 업그레이드 허용 여부
  backup_retention_period     = 3                                # RDS 자동 백업 보존 기간(일)
  deletion_protection         = true                             # RDS 삭제 보호 여부
  skip_final_snapshot         = false                            # RDS 삭제 시 최종 스냅샷 생략 여부
  final_snapshot_identifier   = var.db_final_snapshot_identifier # RDS 삭제 전 최종 스냅샷 이름

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"] # CloudWatch로 내보낼 PostgreSQL 로그 종류

} # 설정 묶음 끝
