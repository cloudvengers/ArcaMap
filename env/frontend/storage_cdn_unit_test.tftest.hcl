mock_provider "aws" {
  override_during = plan

  mock_resource "aws_s3_bucket" {
    defaults = {
      id                          = "test-content-bucket"
      arn                         = "arn:aws:s3:::test-content-bucket"
      bucket_regional_domain_name = "test-content-bucket.s3.ap-northeast-2.amazonaws.com"
    }
  }

  mock_data "aws_route53_zone" {
    defaults = {
      zone_id      = "Z05495112R0T3ZW9NIKIZ"
      name         = "arcamap.app."
      name_servers = ["ns-test.awsdns.com"]
    }
  }

  mock_data "aws_caller_identity" {
    defaults = { account_id = "565725315772" }
  }

  mock_resource "aws_cloudfront_distribution" {
    defaults = {
      id             = "EDISTRIBUTION"
      arn            = "arn:aws:cloudfront::565725315772:distribution/EDISTRIBUTION"
      domain_name    = "test.cloudfront.net"
      hosted_zone_id = "Z2FDTNDATAQYW2"
    }
  }

  mock_resource "aws_cloudwatch_log_delivery_source" {
    defaults = { arn = "arn:aws:logs:us-east-1:565725315772:delivery-source:arcamap-cloudfront" }
  }

  mock_resource "aws_cloudfront_cache_policy" {
    defaults = {}
  }

  mock_resource "aws_cloudfront_response_headers_policy" {
    defaults = { id = "test-security-headers" }
  }
}

mock_provider "aws" {
  alias = "dns"

  mock_data "aws_route53_zone" {
    defaults = {
      zone_id      = "Z05495112R0T3ZW9NIKIZ"
      name         = "arcamap.app."
      name_servers = ["ns-test.awsdns.com"]
    }
  }
}

run "content_bucket_retention" {
  command = plan
  module { source = "../../modules/s3-bucket" }
  variables { bucket_prefix = "arcamap-test-" }

  assert {
    condition = (
      aws_s3_bucket_versioning.main.versioning_configuration[0].status == "Enabled" &&
      length(aws_s3_bucket_lifecycle_configuration.main.rule) == 1 &&
      aws_s3_bucket_lifecycle_configuration.main.rule[0].noncurrent_version_expiration[0].noncurrent_days == 7 &&
      aws_s3_bucket_lifecycle_configuration.main.rule[0].expiration[0].expired_object_delete_marker &&
      aws_s3_bucket_lifecycle_configuration.main.rule[0].abort_incomplete_multipart_upload[0].days_after_initiation == 7
    )
    error_message = "콘텐츠·API 배포 버킷은 현재 객체 만료 없이 버전 관리·이전 버전 7일·삭제 마커·MPU 7일 정리가 필요합니다."
  }
}

run "logs_bucket_retention" {
  command = plan
  module { source = "../../modules/s3-bucket" }
  variables {
    bucket_prefix   = "arcamap-test-logs-"
    expiration_days = 30
  }

  assert {
    condition = (
      aws_s3_bucket_versioning.main.versioning_configuration[0].status == "Enabled" &&
      length(aws_s3_bucket_lifecycle_configuration.main.rule) == 2 &&
      one([for rule in aws_s3_bucket_lifecycle_configuration.main.rule : rule if rule.id == "expire-cloudfront-logs"]).expiration[0].days == 30 &&
      one([for rule in aws_s3_bucket_lifecycle_configuration.main.rule : rule if rule.id == "expire-noncurrent-versions"]).noncurrent_version_expiration[0].noncurrent_days == 7 &&
      one([for rule in aws_s3_bucket_lifecycle_configuration.main.rule : rule if rule.id == "expire-noncurrent-versions"]).expiration[0].expired_object_delete_marker &&
      one([for rule in aws_s3_bucket_lifecycle_configuration.main.rule : rule if rule.id == "expire-noncurrent-versions"]).abort_incomplete_multipart_upload[0].days_after_initiation == 7
    )
    error_message = "로그는 현재 객체 30일과 이전 버전 7일을 별도 규칙으로 적용해야 합니다."
  }
}

run "cloudfront_policy_and_cache" {
  command = plan
  module { source = "../../modules/cloudfront" }
  variables {
    account_id                 = "565725315772"
    certificate_arn            = "arn:aws:acm:us-east-1:565725315772:certificate/8e97257a-a29e-42f6-b78b-04d0ece085fc"
    cloudfront_price_class     = "PriceClass_200"
    frontend_domain_name       = "arcamap.app"
    frontend_cache_ttl_seconds = 300
    media_cache_ttl_seconds    = 86400
    logs_bucket                = { id = "test-logs", arn = "arn:aws:s3:::test-logs" }
    origin_buckets = {
      static = { id = "test-web", arn = "arn:aws:s3:::test-web", bucket_regional_domain_name = "test-web.s3.ap-northeast-2.amazonaws.com" }
      photos = { id = "test-photos", arn = "arn:aws:s3:::test-photos", bucket_regional_domain_name = "test-photos.s3.ap-northeast-2.amazonaws.com" }
      maps   = { id = "test-maps", arn = "arn:aws:s3:::test-maps", bucket_regional_domain_name = "test-maps.s3.ap-northeast-2.amazonaws.com" }
    }
  }

  assert {
    condition = alltrue([
      for policy in concat(values(aws_s3_bucket_policy.origin), [aws_s3_bucket_policy.cloudfront_logs]) :
      length(jsondecode(policy.policy).Statement) == 2 &&
      one([for statement in jsondecode(policy.policy).Statement : statement if statement.Sid == "DenyInsecureTransport"]).Effect == "Deny" &&
      one([for statement in jsondecode(policy.policy).Statement : statement if statement.Sid == "DenyInsecureTransport"]).Principal == "*" &&
      one([for statement in jsondecode(policy.policy).Statement : statement if statement.Sid == "DenyInsecureTransport"]).Action == "s3:*" &&
      toset(one([for statement in jsondecode(policy.policy).Statement : statement if statement.Sid == "DenyInsecureTransport"]).Resource) == toset(["arn:aws:s3:::${policy.bucket}", "arn:aws:s3:::${policy.bucket}/*"]) &&
      one([for statement in jsondecode(policy.policy).Statement : statement if statement.Sid == "DenyInsecureTransport"]).Condition.Bool == {
        "aws:SecureTransport" = "false", "aws:PrincipalIsAWSService" = "false"
      }
    ])
    error_message = "모든 콘텐츠·로그 정책은 버킷·객체에 두 Bool 조건을 함께 사용하는 HTTP 거부와 기존 Allow를 포함해야 합니다."
  }

  assert {
    condition = alltrue([
      for name, policy in aws_s3_bucket_policy.origin :
      jsondecode(policy.policy).Statement[0].Effect == "Allow" &&
      jsondecode(policy.policy).Statement[0].Principal.Service == "cloudfront.amazonaws.com" &&
      jsondecode(policy.policy).Statement[0].Action == "s3:GetObject" &&
      jsondecode(policy.policy).Statement[0].Resource == "${var.origin_buckets[name].arn}/${name == "maps" ? "20260907.pmtiles" : "*"}" &&
      jsondecode(policy.policy).Statement[0].Condition.StringEquals["AWS:SourceArn"] == aws_cloudfront_distribution.site.arn &&
      jsondecode(policy.policy).Statement[0].Condition.StringEquals["AWS:SourceAccount"] == var.account_id
    ])
    error_message = "OAC 읽기는 지정 배포·계정과 기존 객체 범위로 제한해야 합니다."
  }

  assert {
    condition = (
      jsondecode(aws_s3_bucket_policy.cloudfront_logs.policy).Statement[0].Effect == "Allow" &&
      jsondecode(aws_s3_bucket_policy.cloudfront_logs.policy).Statement[0].Principal.Service == "delivery.logs.amazonaws.com" &&
      jsondecode(aws_s3_bucket_policy.cloudfront_logs.policy).Statement[0].Action == "s3:PutObject" &&
      jsondecode(aws_s3_bucket_policy.cloudfront_logs.policy).Statement[0].Resource == "${var.logs_bucket.arn}/AWSLogs/${var.account_id}/CloudFront/*" &&
      jsondecode(aws_s3_bucket_policy.cloudfront_logs.policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] == var.account_id &&
      jsondecode(aws_s3_bucket_policy.cloudfront_logs.policy).Statement[0].Condition.StringEquals["s3:x-amz-acl"] == "bucket-owner-full-control" &&
      jsondecode(aws_s3_bucket_policy.cloudfront_logs.policy).Statement[0].Condition.ArnLike["aws:SourceArn"] == aws_cloudwatch_log_delivery_source.cloudfront.arn
    )
    error_message = "로그 쓰기의 계정·소스 ARN·ACL 조건과 로그 경로를 보존해야 합니다."
  }

  assert {
    condition = (
      aws_cloudfront_cache_policy.frontend.min_ttl == 0 && aws_cloudfront_cache_policy.frontend.default_ttl == 300 && aws_cloudfront_cache_policy.frontend.max_ttl == 300 &&
      aws_cloudfront_cache_policy.assets.min_ttl == 0 && aws_cloudfront_cache_policy.assets.default_ttl == 31536000 && aws_cloudfront_cache_policy.assets.max_ttl == 31536000 &&
      aws_cloudfront_cache_policy.media.min_ttl == 0 && aws_cloudfront_cache_policy.media.default_ttl == 86400 && aws_cloudfront_cache_policy.media.max_ttl == 86400 &&
      aws_cloudfront_distribution.site.default_cache_behavior[0].cache_policy_id == aws_cloudfront_cache_policy.frontend.id &&
      aws_cloudfront_distribution.site.default_cache_behavior[0].compress &&
      length(aws_cloudfront_distribution.site.ordered_cache_behavior) == 3 &&
      alltrue([for behavior in aws_cloudfront_distribution.site.ordered_cache_behavior :
        behavior.cache_policy_id == (behavior.path_pattern == "/assets/*" ? aws_cloudfront_cache_policy.assets.id : aws_cloudfront_cache_policy.media.id) &&
        behavior.target_origin_id == lookup({ "/assets/*" = "static", "/photos/*" = "photos", "/20260907.pmtiles" = "maps" }, behavior.path_pattern, "invalid") &&
        behavior.compress == (behavior.path_pattern == "/assets/*")
      ]) &&
      alltrue([for behavior in concat(aws_cloudfront_distribution.site.default_cache_behavior, aws_cloudfront_distribution.site.ordered_cache_behavior) :
        behavior.response_headers_policy_id == aws_cloudfront_response_headers_policy.security.id &&
        behavior.viewer_protocol_policy == "redirect-to-https" && toset(behavior.allowed_methods) == toset(["GET", "HEAD"]) && toset(behavior.cached_methods) == toset(["GET", "HEAD"])
      ])
    )
    error_message = "HTML·assets·사진·지도는 지정 캐시/압축/오리진 및 동일 보안 헤더 정책을 사용해야 합니다."
  }

  assert {
    condition = alltrue([for policy in [aws_cloudfront_cache_policy.frontend, aws_cloudfront_cache_policy.assets, aws_cloudfront_cache_policy.media] :
      policy.parameters_in_cache_key_and_forwarded_to_origin[0].cookies_config[0].cookie_behavior == "none" &&
      policy.parameters_in_cache_key_and_forwarded_to_origin[0].headers_config[0].header_behavior == "none" &&
      policy.parameters_in_cache_key_and_forwarded_to_origin[0].query_strings_config[0].query_string_behavior == "none" &&
      policy.parameters_in_cache_key_and_forwarded_to_origin[0].enable_accept_encoding_gzip == (policy.name != "arcamap-media") &&
      policy.parameters_in_cache_key_and_forwarded_to_origin[0].enable_accept_encoding_brotli == (policy.name != "arcamap-media")
    ])
    error_message = "캐시 키의 쿠키·헤더·쿼리 제외 및 웹만 gzip/Brotli 허용을 유지해야 합니다."
  }

  assert {
    condition = (
      aws_cloudfront_response_headers_policy.security.security_headers_config[0].strict_transport_security[0].access_control_max_age_sec == 31536000 &&
      !aws_cloudfront_response_headers_policy.security.security_headers_config[0].strict_transport_security[0].include_subdomains &&
      !aws_cloudfront_response_headers_policy.security.security_headers_config[0].strict_transport_security[0].preload &&
      aws_cloudfront_response_headers_policy.security.security_headers_config[0].strict_transport_security[0].override &&
      aws_cloudfront_response_headers_policy.security.security_headers_config[0].content_type_options[0].override &&
      aws_cloudfront_response_headers_policy.security.security_headers_config[0].frame_options[0].frame_option == "DENY" &&
      aws_cloudfront_response_headers_policy.security.security_headers_config[0].frame_options[0].override &&
      aws_cloudfront_response_headers_policy.security.security_headers_config[0].referrer_policy[0].referrer_policy == "strict-origin-when-cross-origin" &&
      aws_cloudfront_response_headers_policy.security.security_headers_config[0].referrer_policy[0].override &&
      aws_cloudfront_response_headers_policy.security.security_headers_config[0].content_security_policy[0].override &&
      aws_cloudfront_response_headers_policy.security.security_headers_config[0].content_security_policy[0].content_security_policy == "default-src 'self'; script-src 'self'; style-src 'self'; style-src-attr 'unsafe-inline'; img-src 'self' data: blob: https://protomaps.github.io/basemaps-assets/; font-src 'self'; connect-src 'self' https://api.arcamap.app https://protomaps.github.io/basemaps-assets/; worker-src 'self'; object-src 'none'; base-uri 'none'; frame-src 'none'; frame-ancestors 'none'; form-action 'self';"
    )
    error_message = "보안 헤더는 MADR의 HSTS/CSP/프레임/참조 정책을 모두 덮어쓰기 적용해야 합니다."
  }
}

run "frontend_existing_maps_and_outputs" {
  command = plan

  override_resource {
    target = aws_s3_bucket.maps
    values = {
      id                          = "protomaps-565725315772-ap-northeast-2-an"
      arn                         = "arn:aws:s3:::protomaps-565725315772-ap-northeast-2-an"
      bucket_regional_domain_name = "protomaps-565725315772-ap-northeast-2-an.s3.ap-northeast-2.amazonaws.com"
    }
  }
  override_resource { target = aws_s3_bucket_public_access_block.maps }
  override_resource { target = aws_s3_bucket_ownership_controls.maps }
  override_resource { target = aws_s3_bucket_server_side_encryption_configuration.maps }
  override_resource { target = aws_s3_bucket_cors_configuration.maps }
  override_resource { target = aws_s3_bucket_versioning.maps }
  override_data {
    target = data.aws_route53_zone.frontend
    values = {
      zone_id      = "Z05495112R0T3ZW9NIKIZ"
      name         = "arcamap.app."
      name_servers = ["ns-test.awsdns.com"]
    }
  }
  assert {
    condition = (
      toset(keys(module.buckets)) == toset(["static", "photos", "cloudfront_logs"]) &&
      toset(keys(output.s3_buckets)) == toset(["static", "photos", "cloudfront_logs", "maps"]) &&
      toset(keys(output.s3_bucket_arns)) == toset(["static", "photos", "cloudfront_logs", "maps"]) &&
      output.s3_buckets.maps == aws_s3_bucket.maps.id && output.s3_bucket_arns.maps == aws_s3_bucket.maps.arn &&
      aws_s3_bucket_versioning.maps.bucket == aws_s3_bucket.maps.id &&
      aws_s3_bucket_versioning.maps.versioning_configuration[0].status == "Enabled" &&
      length(aws_s3_bucket_lifecycle_configuration.maps.rule) == 1 &&
      aws_s3_bucket_lifecycle_configuration.maps.rule[0].noncurrent_version_expiration[0].noncurrent_days == 7 &&
      aws_s3_bucket_lifecycle_configuration.maps.rule[0].expiration[0].expired_object_delete_marker &&
      aws_s3_bucket_lifecycle_configuration.maps.rule[0].abort_incomplete_multipart_upload[0].days_after_initiation == 7
    )
    error_message = "지도 버킷은 신규 생성 대상에서 제외하고 기존 식별자에 보존 설정과 출력 계약을 연결해야 합니다."
  }
}
