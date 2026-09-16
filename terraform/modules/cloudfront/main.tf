locals {
  map_object_key = "20260907.pmtiles"
}

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "arcamap-s3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_cache_policy" "frontend" {
  name        = "arcamap-frontend"
  min_ttl     = 0
  default_ttl = var.frontend_cache_ttl_seconds
  max_ttl     = var.frontend_cache_ttl_seconds

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_cache_policy" "media" {
  name        = "arcamap-media"
  min_ttl     = 0
  default_ttl = var.media_cache_ttl_seconds
  max_ttl     = var.media_cache_ttl_seconds

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = false
    enable_accept_encoding_brotli = false

    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = [var.frontend_domain_name]
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  price_class         = var.cloudfront_price_class
  wait_for_deployment = true
  web_acl_id          = aws_wafv2_web_acl.site.arn

  origin {
    origin_id                = "static"
    domain_name              = var.origin_buckets.static.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
    connection_attempts      = 3
    connection_timeout       = 10
  }

  origin {
    origin_id                = "photos"
    domain_name              = var.origin_buckets.photos.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
    connection_attempts      = 3
    connection_timeout       = 10
  }

  origin {
    origin_id                = "maps"
    domain_name              = var.origin_buckets.maps.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
    connection_attempts      = 3
    connection_timeout       = 10
  }

  default_cache_behavior {
    target_origin_id       = "static"
    cache_policy_id        = aws_cloudfront_cache_policy.frontend.id
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  ordered_cache_behavior {
    path_pattern           = "/photos/*"
    target_origin_id       = "photos"
    cache_policy_id        = aws_cloudfront_cache_policy.media.id
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = false
  }

  ordered_cache_behavior {
    path_pattern           = "/${local.map_object_key}"
    target_origin_id       = "maps"
    cache_policy_id        = aws_cloudfront_cache_policy.media.id
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = false
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2025"
  }
}

resource "aws_cloudwatch_log_delivery_source" "cloudfront" {
  region       = "us-east-1"
  name         = "arcamap-cloudfront"
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.site.arn
}

resource "aws_cloudwatch_log_delivery_destination" "cloudfront" {
  region        = "us-east-1"
  name          = "arcamap-cloudfront"
  output_format = "json"

  delivery_destination_configuration {
    destination_resource_arn = var.logs_bucket.arn
  }
}

resource "aws_cloudwatch_log_delivery" "cloudfront" {
  region                   = "us-east-1"
  delivery_source_name     = aws_cloudwatch_log_delivery_source.cloudfront.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cloudfront.arn

  depends_on = [aws_s3_bucket_policy.cloudfront_logs]
}

resource "aws_s3_bucket_policy" "origin" {
  for_each = var.origin_buckets

  bucket = each.value.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontRead"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${each.value.arn}/${each.key == "maps" ? local.map_object_key : "*"}"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.site.arn
        }
      }
    }]
  })
}

resource "aws_s3_bucket_policy" "cloudfront_logs" {
  bucket = var.logs_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AWSLogsDeliveryWrite"
      Effect    = "Allow"
      Principal = { Service = "delivery.logs.amazonaws.com" }
      Action    = "s3:PutObject"
      Resource  = "${var.logs_bucket.arn}/AWSLogs/${var.account_id}/CloudFront/*"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = var.account_id
          "s3:x-amz-acl"      = "bucket-owner-full-control"
        }
        ArnLike = {
          "aws:SourceArn" = aws_cloudwatch_log_delivery_source.cloudfront.arn
        }
      }
    }]
  })
}
