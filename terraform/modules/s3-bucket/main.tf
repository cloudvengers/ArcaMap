resource "aws_s3_bucket" "main" {
  bucket_prefix    = var.bucket_prefix
  bucket_namespace = "global"
  force_destroy    = false
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket                  = aws_s3_bucket.main.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "main" {
  count = var.noncurrent_retention_days == null ? 0 : 1

  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count = var.noncurrent_retention_days != null || var.expiration_days != null ? 1 : 0

  bucket = aws_s3_bucket.main.id

  dynamic "rule" {
    for_each = var.noncurrent_retention_days == null ? [] : [var.noncurrent_retention_days]

    content {
      id     = "expire-noncurrent-versions"
      status = "Enabled"

      filter {}

      noncurrent_version_expiration {
        noncurrent_days = rule.value
      }

      expiration {
        expired_object_delete_marker = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.expiration_days == null ? [] : [var.expiration_days]

    content {
      id     = "expire-cloudfront-logs"
      status = "Enabled"

      filter {}

      expiration {
        days = rule.value
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.main]
}
