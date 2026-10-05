locals {
  api_artifact_path   = coalesce(var.api_artifact_path, "${path.module}/../../app/was/.artifacts/was.tar.gz")
  api_artifact_sha256 = var.enable_image_builder ? filesha256(local.api_artifact_path) : null
  api_artifact_key    = "was/${coalesce(local.api_artifact_sha256, "not-ready")}.tar.gz"
  database_roles      = { api = "arcamap_api", image_builder = "arcamap_imagebuilder" }

  api_environment = join("\n", [
    "AWS_REGION=${var.database.region}",
    "PGHOST=${var.database.host}",
    "DSQL_AUTH_HOST=${var.database.auth_host}",
    "PGPORT=${var.database.port}",
    "PGDATABASE=${var.database.dbname}",
    "PGUSER=${local.database_roles.api}",
    "PGSSLMODE=verify-full",
    "PGSSLROOTCERT=/etc/ssl/certs/Amazon_Root_CA_1.pem",
    "",
  ])

  api_service = file("${path.module}/../../app/was/deploy/arcamap-api.service")
}

module "deployment_bucket" {
  source = "../../modules/s3-bucket"

  bucket_prefix             = "arcamap-deploy-"
  noncurrent_retention_days = 7
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
      Condition = {
        Bool = {
          "aws:SecureTransport"       = "false"
          "aws:PrincipalIsAWSService" = "false"
        }
      }
    }]
  })
}

resource "aws_s3_object" "api" {
  count = var.enable_image_builder ? 1 : 0

  bucket      = module.deployment_bucket.bucket.id
  key         = local.api_artifact_key
  source      = local.api_artifact_path
  source_hash = local.api_artifact_sha256

  depends_on = [aws_s3_bucket_policy.deployment]
}
