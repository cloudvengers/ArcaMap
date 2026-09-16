locals {
  api_artifact_path = "${path.module}/../../../was/.artifacts/was.tar.gz"
  api_artifact_key  = "was/${filesha256(local.api_artifact_path)}.tar.gz"
}

module "deployment_bucket" {
  source = "../../modules/s3-bucket"

  bucket_prefix = "arcamap-deploy-"
}

resource "aws_s3_bucket_policy" "deployment" {
  bucket = module.deployment_bucket.bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [module.deployment_bucket.bucket.arn, "${module.deployment_bucket.bucket.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

resource "aws_s3_object" "api" {
  bucket      = module.deployment_bucket.bucket.id
  key         = local.api_artifact_key
  source      = local.api_artifact_path
  source_hash = filesha256(local.api_artifact_path)

  # 이 객체를 사용하는 이미지 빌드 전에 인증정보와 조회 권한을 준비합니다.
  depends_on = [
    aws_s3_bucket_policy.deployment,
    aws_secretsmanager_secret_version.database,
    aws_iam_role_policy.api_secret,
    aws_iam_role_policy.imagebuilder_artifact,
  ]
}

resource "aws_secretsmanager_secret" "database" {
  name        = "arcamap/api/database"
  description = "Arcamap FastAPI systemd environment for the existing RDS database."
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  # systemd EnvironmentFile 문법입니다. 비밀번호는 상태·계획 파일에 저장하지 않습니다.
  secret_string_wo = join("\n", [
    "PGHOST=${data.aws_db_instance.postgres.address}",
    "PGPORT=${data.aws_db_instance.postgres.port}",
    "PGDATABASE=${data.aws_db_instance.postgres.db_name}",
    "PGUSER=${data.aws_db_instance.postgres.master_username}",
    format("PGPASSWORD=\"%s\"", replace(replace(var.db_password, "\\", "\\\\"), "\"", "\\\"")),
    "PGSSLROOTCERT=/etc/arcamap/rds-ap-northeast-2-bundle.pem",
    "",
  ])
  # 기존 RDS 비밀번호를 변경해 다시 공급할 때 함께 증가시킵니다.
  secret_string_wo_version = 1
}
