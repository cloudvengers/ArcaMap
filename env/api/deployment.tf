locals {                                                                     # 이 모듈에서 공유할 로컬 값
  api_artifact_path   = "${path.module}/../../app/was/.artifacts/was.tar.gz" # 로컬 API 배포 아카이브 경로
  api_artifact_sha256 = filesha256(local.api_artifact_path)                  # 배포 아카이브의 SHA-256 무결성 값
  api_artifact_key    = "was/${local.api_artifact_sha256}.tar.gz"            # 내용 해시로 구분한 배포 객체 키
}                                                                            # 설정 묶음 끝

module "deployment_bucket" {         # API 배포용 S3 모듈 연결
  source = "../../modules/s3-bucket" # 로컬 하위 모듈 경로

  bucket_prefix = "arcamap-deploy-" # 고유 접미사를 붙일 버킷 이름 접두사
}                                   # 설정 묶음 끝

resource "aws_s3_bucket_policy" "deployment" {                                                      # S3 버킷 정책 정의
  bucket = module.deployment_bucket.bucket.id                                                       # 대상 S3 버킷 이름 또는 ID
  policy = jsonencode({                                                                             # 접근 권한 정책을 JSON으로 변환
    Version = "2012-10-17"                                                                          # IAM 정책 문서 버전
    Statement = [{                                                                                  # IAM 정책의 권한 문장 목록
      Sid       = "DenyInsecureTransport"                                                           # 권한 문장 식별자
      Effect    = "Deny"                                                                            # 권한 허용 또는 거부 동작
      Principal = "*"                                                                               # 이 정책을 적용할 접근 주체
      Action    = "s3:*"                                                                            # 허용하거나 거부할 AWS 작업
      Resource  = [module.deployment_bucket.bucket.arn, "${module.deployment_bucket.bucket.arn}/*"] # 권한을 적용할 리소스 ARN
      Condition = { Bool = { "aws:SecureTransport" = "false" } }                                    # 정책을 적용할 추가 조건
    }]                                                                                              # 설정 묶음 끝
  })                                                                                                # 설정 묶음 끝
}                                                                                                   # 설정 묶음 끝

resource "aws_s3_object" "api" {                   # API 배포 객체 정의
  bucket      = module.deployment_bucket.bucket.id # 대상 S3 버킷 이름 또는 ID
  key         = local.api_artifact_key             # S3 배포 객체 키
  source      = local.api_artifact_path            # 업로드할 로컬 아카이브 경로
  source_hash = local.api_artifact_sha256          # 배포 객체 내용 변경 감지용 해시

  depends_on = [aws_s3_bucket_policy.deployment] # 참조만으로 표현되지 않는 선행 작업 지정
}                                                # 설정 묶음 끝

resource "aws_secretsmanager_secret" "database" {                                    # DB 접속 정보용 Secret 정의
  name        = "arcamap/api/database"                                               # AWS 리소스·규칙·작업 이름
  description = "Arcamap FastAPI systemd environment for the existing RDS database." # 리소스·경보의 용도 설명
}                                                                                    # 설정 묶음 끝

resource "aws_secretsmanager_secret_version" "database" { # DB 접속 정보 Secret 버전 정의
  secret_id = aws_secretsmanager_secret.database.id       # 접속 정보를 저장할 Secret ID
  # systemd EnvironmentFile 문법입니다. 비밀번호는 상태·계획 파일에 저장하지 않습니다.
  secret_string_wo = join("\n", [                                                               # 상태·계획에 저장하지 않는 DB 접속 정보
    "PGHOST=${data.aws_db_instance.postgres.address}",                                          # API가 접속할 RDS 주소
    "PGPORT=${data.aws_db_instance.postgres.port}",                                             # API가 접속할 PostgreSQL 포트
    "PGDATABASE=${data.aws_db_instance.postgres.db_name}",                                      # API가 사용할 데이터베이스 이름
    "PGUSER=${data.aws_db_instance.postgres.master_username}",                                  # API가 사용할 DB 사용자 이름
    format("PGPASSWORD=\"%s\"", replace(replace(var.db_password, "\\", "\\\\"), "\"", "\\\"")), # 환경 파일 문법에 맞게 비밀번호 이스케이프
    "PGSSLROOTCERT=/etc/arcamap/rds-ap-northeast-2-bundle.pem",                                 # RDS TLS 검증용 CA 인증서 경로
    "",                                                                                         # 환경 파일 마지막 줄바꿈 추가
  ])                                                                                            # 설정 묶음 끝
  # 기존 RDS 비밀번호를 변경해 다시 공급할 때 함께 증가시킵니다.
  secret_string_wo_version = 1 # 접속 정보 쓰기 변경을 알리는 버전
}                              # 설정 묶음 끝
