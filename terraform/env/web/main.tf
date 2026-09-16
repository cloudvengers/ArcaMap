data "aws_caller_identity" "current" {}

data "aws_s3_bucket" "maps" {
  bucket = "protomaps-565725315772-ap-northeast-2-an"
}

data "aws_acm_certificate" "site" {
  region      = "us-east-1"
  domain      = var.frontend_domain_name
  statuses    = ["ISSUED"]
  most_recent = false
}

module "buckets" {
  for_each = {
    static = {
      bucket_prefix             = "arcamap-static-"
      expiration_days           = null
      noncurrent_retention_days = null
    }
    photos = {
      bucket_prefix             = "arcamap-photos-"
      expiration_days           = null
      noncurrent_retention_days = var.photo_noncurrent_retention_days
    }
    cloudfront_logs = {
      bucket_prefix             = "arcamap-cloudfront-logs-"
      expiration_days           = var.log_retention_days
      noncurrent_retention_days = null
    }
  }
  source = "../../modules/s3-bucket"

  bucket_prefix             = each.value.bucket_prefix
  expiration_days           = each.value.expiration_days
  noncurrent_retention_days = each.value.noncurrent_retention_days
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  account_id                 = data.aws_caller_identity.current.account_id
  certificate_arn            = data.aws_acm_certificate.site.arn
  frontend_domain_name       = var.frontend_domain_name
  frontend_cache_ttl_seconds = var.frontend_cache_ttl_seconds
  media_cache_ttl_seconds    = var.media_cache_ttl_seconds
  cloudfront_price_class     = var.cloudfront_price_class
  logs_bucket                = module.buckets["cloudfront_logs"].bucket
  origin_buckets = {
    static = module.buckets["static"].bucket
    photos = module.buckets["photos"].bucket
    maps = {
      id                          = data.aws_s3_bucket.maps.id
      arn                         = data.aws_s3_bucket.maps.arn
      bucket_regional_domain_name = data.aws_s3_bucket.maps.bucket_regional_domain_name
    }
  }
}

resource "aws_route53_record" "frontend" {
  for_each = toset(["A", "AAAA"])
  provider = aws.dns

  zone_id         = var.route53_zone_id
  name            = var.frontend_domain_name
  type            = each.key
  allow_overwrite = false

  alias {
    name                   = module.cloudfront.cloudfront.domain_name
    zone_id                = module.cloudfront.cloudfront.hosted_zone_id
    evaluate_target_health = false
  }
}
